import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:restora_frontend/core/api/api_client.dart';
import 'package:restora_frontend/core/platform/token_store.dart';
import 'package:restora_frontend/features/authentication/data/auth_repository.dart';
import 'package:restora_frontend/features/authentication/state/auth_controller.dart';
import 'package:restora_frontend/features/exercise/data/assignment.dart';
import 'package:restora_frontend/features/exercise/platform/pose_source.dart';
import 'package:restora_frontend/features/sessions/data/session_repository.dart';
import 'package:restora_frontend/features/sessions/data/session_summary.dart';

/// Synthetic data used only by widget tests and optional local UI previews.
const uxAssignment = Assignment(
  id: 'assignment-demo',
  exerciseId: 'elbow_flexion_extension',
  title: 'Elbow flexion and extension',
  description: 'Explore one complete elbow movement using simulated input.',
  instructions: [
    'Extend the elbow to establish the starting position.',
    'Flex the elbow, then return to extension for one complete cycle.',
    'Demonstration defaults require professional review before patient use.',
  ],
  targetRepetitions: 10,
  flexedThreshold: 70,
  extendedThreshold: 150,
);

Map<String, dynamic> assignmentPayload() => {
  'id': uxAssignment.id,
  'exercise_id': uxAssignment.exerciseId,
  'title': uxAssignment.title,
  'description': uxAssignment.description,
  'instructions': uxAssignment.instructions,
  'target_repetitions': uxAssignment.targetRepetitions,
  'flexed_threshold_degrees': uxAssignment.flexedThreshold,
  'extended_threshold_degrees': uxAssignment.extendedThreshold,
  'demonstration_only': true,
  'professional_review_required': true,
};

class UxFixture {
  UxFixture({Future<http.Response> Function(http.Request)? handle}) {
    final claims = base64Url.encode(utf8.encode('{"sub":"synthetic-account"}'));
    final token = 'header.$claims.signature';
    api = ApiClient(
      baseUrl: Uri.parse('https://api.example.test'),
      token: () => auth.token,
      client: MockClient(
        handle ??
            (_) async => http.Response(jsonEncode(assignmentPayload()), 200),
      ),
    );
    auth = AuthController(AuthRepository(api), _MemoryTokenStore())
      ..token = token;
  }

  late final ApiClient api;
  late final AuthController auth;

  void dispose() {
    auth.dispose();
    api.close();
  }
}

class _MemoryTokenStore implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

class UxPoseSource implements PoseSource {
  final _samples = StreamController<PoseSample>.broadcast(sync: true);

  @override
  String get trackingMode => 'simulated';
  @override
  Stream<PoseSample> get samples => _samples.stream;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() => _samples.close();

  void completeCycle() {
    for (final sample in const [
      (0, 160.0),
      (240, 160.0),
      (300, 60.0),
      (540, 60.0),
      (600, 160.0),
      (840, 160.0),
    ]) {
      _samples.add(
        PoseSample(
          elapsed: Duration(milliseconds: sample.$1),
          elbowAngle: sample.$2,
          confidence: 1,
        ),
      );
    }
  }
}

class UxSessions implements SessionRepository {
  final submissions = <SessionSummary>[];
  List<SavedSession> records = [
    SavedSession(
      id: 'saved-demo',
      clientSessionId: 'client-demo',
      repetitions: 6,
      startedAt: DateTime.utc(2026, 10, 16, 8, 15),
      trackingMode: 'simulated',
      stopReason: 'user_stopped',
    ),
    SavedSession(
      id: 'saved-interrupted-demo',
      clientSessionId: 'client-interrupted-demo',
      repetitions: 2,
      startedAt: DateTime.utc(2026, 10, 15, 9, 20),
      trackingMode: 'simulated',
      stopReason: 'tracking_lost',
    ),
  ];
  Object? failure;

  @override
  Future<List<SavedSession>> history() async {
    if (failure case final error?) throw error;
    return records;
  }

  @override
  Future<SavedSession> save(SessionSummary summary) async {
    submissions.add(summary);
    if (failure case final error?) throw error;
    return SavedSession(
      id: 'saved-session',
      clientSessionId: summary.clientSessionId,
      repetitions: summary.completedRepetitions,
      startedAt: summary.startedAt,
      trackingMode: summary.trackingMode,
      stopReason: summary.stopReason,
    );
  }
}
