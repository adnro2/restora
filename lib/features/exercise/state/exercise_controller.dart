import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_exception.dart';
import '../../sessions/data/session_repository.dart';
import '../../sessions/data/session_summary.dart';
import '../data/assignment.dart';
import '../platform/pose_source.dart';
import 'rep_counter.dart';

class ExerciseController extends ChangeNotifier {
  ExerciseController({
    required this.assignment,
    required this.source,
    required this.sessions,
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? const Uuid().v4,
       counter = RepCounter(
         flexedThreshold: assignment.flexedThreshold,
         extendedThreshold: assignment.extendedThreshold,
       );

  final Assignment assignment;
  final PoseSource source;
  final SessionRepository sessions;
  final RepCounter counter;
  final DateTime Function() _now;
  final String Function() _newId;
  final Stopwatch _silence = Stopwatch();
  StreamSubscription<PoseSample>? _subscription;
  Timer? _watchdog;
  DateTime? _startedAt;
  String? _clientId;
  bool _disposed = false;
  bool _inactiveWhileStarting = false;
  bool running = false, starting = false, saving = false;
  bool authenticationRequired = false;
  SessionSummary? pending;
  SavedSession? saved;
  String? error;
  double? angle;

  String get trackingStatus => !running
      ? 'Stopped'
      : counter.tracking
      ? 'Simulated landmarks available'
      : 'Tracking interrupted — partial cycle reset';

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (running || starting || pending != null || saved != null) return;
    starting = true;
    _inactiveWhileStarting = false;
    error = null;
    _changed();
    counter.reset();
    _startedAt = _now().toUtc();
    _clientId = _newId();
    _subscription = source.samples.listen(
      (sample) {
        if (!running) return;
        _silence
          ..reset()
          ..start();
        counter.add(sample);
        angle = sample.usable ? sample.elbowAngle : null;
        _changed();
      },
      onError: (Object failure) {
        if (running) unawaited(stop('tracking_lost'));
      },
      onDone: () {
        if (running) unawaited(stop('tracking_lost'));
      },
    );
    try {
      await source.start();
      if (_disposed) {
        await source.stop();
        return;
      }
      if (_inactiveWhileStarting) {
        // The native start may finish after the app has left the foreground.
        // Immediately stop and freeze; never arm counting or the watchdog.
        running = true;
        await stop('app_inactive');
        return;
      }
      running = true;
      _silence
        ..reset()
        ..start();
      _watchdog = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (_silence.elapsed > const Duration(milliseconds: 500)) {
          counter.interrupt();
          angle = null;
          _changed();
        }
        if (_silence.elapsed > const Duration(seconds: 5)) {
          unawaited(stop('tracking_lost'));
        }
      });
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      try {
        await source.stop();
      } catch (_) {
        /* Preserve the startup error. */
      }
      error = 'Could not start tracking input. Please try again.';
    } finally {
      starting = false;
      _changed();
    }
  }

  Future<void> appInactive() async {
    if (starting) _inactiveWhileStarting = true;
    if (running) await stop('app_inactive');
  }

  Future<void> stop([String reason = 'user_stopped']) async {
    if (!running) return;
    // Freeze synchronously before stopping services or issuing a request.
    running = false;
    final stoppedAt = _now().toUtc();
    pending = SessionSummary(
      clientSessionId: _clientId!,
      assignmentId: assignment.id,
      exerciseId: assignment.exerciseId,
      startedAt: _startedAt!,
      endedAt: stoppedAt.isBefore(_startedAt!) ? _startedAt! : stoppedAt,
      completedRepetitions: counter.repetitions,
      trackingMode: source.trackingMode,
      stopReason: reason,
    );
    counter.interrupt();
    _watchdog?.cancel();
    _silence.stop();
    _changed();
    await _subscription?.cancel();
    _subscription = null;
    try {
      await source.stop();
    } catch (_) {
      /* Summary is already frozen. */
    }
    await retrySave();
  }

  Future<void> retrySave() async {
    final summary = pending;
    if (summary == null || saving || saved != null) return;
    saving = true;
    error = null;
    authenticationRequired = false;
    _changed();
    try {
      saved = await sessions.save(summary);
      pending = null;
    } catch (failure) {
      error = errorMessage(failure);
      authenticationRequired =
          failure is ApiException && failure.isUnauthorized;
    } finally {
      saving = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    running = false;
    _watchdog?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(source.dispose());
    super.dispose();
  }
}
