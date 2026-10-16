import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:restora_frontend/core/api/api_exception.dart';
import 'package:restora_frontend/features/exercise/data/assignment.dart';
import 'package:restora_frontend/features/exercise/platform/pose_source.dart';
import 'package:restora_frontend/features/exercise/state/exercise_controller.dart';
import 'package:restora_frontend/features/sessions/data/session_repository.dart';
import 'package:restora_frontend/features/sessions/data/session_summary.dart';

const assignment = Assignment(
  id: 'assignment',
  exerciseId: 'elbow_flexion_extension',
  title: 'Demo',
  description: 'Demonstration defaults',
  instructions: [],
  targetRepetitions: 10,
  flexedThreshold: 70,
  extendedThreshold: 150,
);

class FakeSource implements PoseSource {
  final stream = StreamController<PoseSample>.broadcast(sync: true);
  Completer<void>? startGate;
  bool stopped = false;
  @override
  String get trackingMode => 'simulated';
  @override
  Stream<PoseSample> get samples => stream.stream;
  @override
  Future<void> start() async {
    await startGate?.future;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> dispose() async {
    await stream.close();
  }

  void emit(int time, double angle) => stream.add(
    PoseSample(
      elapsed: Duration(milliseconds: time),
      elbowAngle: angle,
      confidence: 1,
    ),
  );
}

class FakeSessions implements SessionRepository {
  final payloads = <SessionSummary>[];
  Object? failure;
  Completer<void>? saveGate;
  @override
  Future<SavedSession> save(SessionSummary summary) async {
    payloads.add(summary);
    await saveGate?.future;
    if (failure case final error?) throw error;
    return SavedSession(
      id: 'server-id',
      clientSessionId: summary.clientSessionId,
      repetitions: summary.completedRepetitions,
      startedAt: summary.startedAt,
      trackingMode: summary.trackingMode,
      stopReason: summary.stopReason,
    );
  }

  @override
  Future<List<SavedSession>> history() async => [];
}

void main() {
  late FakeSource source;
  late FakeSessions sessions;
  late ExerciseController controller;
  late DateTime now;
  var ids = 0;
  void cycle() {
    for (final entry in [
      (0, 160.0),
      (240, 160.0),
      (300, 60.0),
      (540, 60.0),
      (600, 160.0),
      (840, 160.0),
    ]) {
      source.emit(entry.$1, entry.$2);
    }
  }

  setUp(() {
    source = FakeSource();
    sessions = FakeSessions();
    ids = 0;
    now = DateTime.utc(2026, 10, 16, 8);
    controller = ExerciseController(
      assignment: assignment,
      source: source,
      sessions: sessions,
      now: () => now,
      newId: () => 'client-${++ids}',
    );
  });
  tearDown(() => controller.dispose());

  test(
    'failed save retains immutable summary, retries same UUID and payload',
    () async {
      sessions.failure = const ApiException(
        'network_error',
        'Connection failed',
      );
      await controller.start();
      cycle();
      now = now.add(const Duration(seconds: 3));
      await controller.stop();
      final frozen = controller.pending!;
      final payload = jsonEncode(frozen.toJson());
      expect(frozen.completedRepetitions, 1);
      expect(controller.running, false);
      expect(controller.error, 'Connection failed');
      now = now.add(const Duration(hours: 2));
      source.emit(900, 60);
      source.emit(1200, 160);
      await controller.start(); // Must not replace a pending summary.
      await controller.retrySave();
      expect(ids, 1);
      expect(identical(sessions.payloads[0], sessions.payloads[1]), true);
      expect(jsonEncode(controller.pending!.toJson()), payload);
      sessions.failure = null;
      await controller.retrySave();
      expect(jsonEncode(sessions.payloads.last.toJson()), payload);
      expect(controller.pending, isNull);
      expect(controller.saved!.clientSessionId, 'client-1');
    },
  );

  test(
    'stop freezes before network response and blocks concurrent retries',
    () async {
      sessions.saveGate = Completer<void>();
      await controller.start();
      cycle();
      final stopping = controller.stop();
      expect(controller.pending!.completedRepetitions, 1);
      await Future<void>.delayed(Duration.zero);
      expect(controller.saving, true);
      await controller.retrySave();
      expect(sessions.payloads, hasLength(1));
      sessions.saveGate!.complete();
      await stopping;
      expect(controller.saved, isNotNull);
    },
  );

  test(
    'authentication error retains summary for in-place reauthentication',
    () async {
      sessions.failure = const ApiException(
        'unauthorized',
        'Sign in again',
        statusCode: 401,
      );
      await controller.start();
      await controller.stop();
      final frozen = controller.pending;
      expect(controller.authenticationRequired, true);
      sessions.failure = null;
      await controller.retrySave();
      expect(identical(sessions.payloads.last, frozen), true);
      expect(controller.saved, isNotNull);
    },
  );

  test(
    'app inactivity stops session and discards incomplete movement',
    () async {
      await controller.start();
      source.emit(0, 160);
      source.emit(240, 160);
      source.emit(300, 60);
      source.emit(540, 60);
      await controller.appInactive();
      expect(controller.running, false);
      expect(source.stopped, true);
      expect(sessions.payloads.single.stopReason, 'app_inactive');
      expect(sessions.payloads.single.completedRepetitions, 0);
    },
  );

  test(
    'pause during asynchronous source startup never enables counting',
    () async {
      source.startGate = Completer<void>();
      final starting = controller.start();
      expect(controller.starting, true);
      await controller.appInactive();
      cycle();
      source.startGate!.complete();
      await starting;
      expect(controller.running, false);
      expect(source.stopped, true);
      expect(sessions.payloads.single.stopReason, 'app_inactive');
      expect(sessions.payloads.single.completedRepetitions, 0);
    },
  );
}
