import 'dart:io';

import 'package:uuid/uuid.dart';

import 'package:restora_frontend/core/api/api_client.dart';
import 'package:restora_frontend/core/api/api_exception.dart';
import 'package:restora_frontend/features/authentication/data/auth_repository.dart';
import 'package:restora_frontend/features/exercise/data/assignment_repository.dart';
import 'package:restora_frontend/features/sessions/data/session_repository.dart';
import 'package:restora_frontend/features/sessions/data/session_summary.dart';

/// Real HTTP smoke test using the same repositories as the application.
/// Requires a running migrated backend and seeded synthetic account.
/// Writes one clearly simulated session. No device/camera validation is implied.
Future<void> main() async {
  final environment = Platform.environment;
  final password = environment['DEMO_PASSWORD'];
  if (password == null || password.isEmpty) {
    stderr.writeln(
      'Set DEMO_PASSWORD to the seeded synthetic account password.',
    );
    exitCode = 2;
    return;
  }
  String? token;
  final api = ApiClient(
    baseUrl: Uri.parse(environment['API_BASE_URL'] ?? 'http://127.0.0.1:8000'),
    token: () => token,
  );
  try {
    token = await AuthRepository(
      api,
    ).login(environment['DEMO_EMAIL'] ?? 'demo@example.test', password);
    final assignment = await AssignmentRepository(api).fetch();
    final sessions = ApiSessionRepository(api);
    final stopped = DateTime.now().toUtc();
    final summary = SessionSummary(
      clientSessionId: const Uuid().v4(),
      assignmentId: assignment.id,
      exerciseId: assignment.exerciseId,
      startedAt: stopped.subtract(const Duration(seconds: 20)),
      endedAt: stopped,
      completedRepetitions: 2,
      trackingMode: 'simulated',
      stopReason: 'user_stopped',
    );
    final created = await sessions.save(summary);
    final retried = await sessions.save(summary);
    if (created.id != retried.id) throw StateError('Retry created a duplicate');
    try {
      await api.post('/v1/sessions', {
        ...summary.toJson(),
        'completed_repetitions': 3,
      });
      throw StateError('Conflicting UUID reuse was accepted');
    } on ApiException catch (error) {
      if (error.statusCode != 409) rethrow;
    }
    final history = await sessions.history();
    final matching = history.where(
      (session) => session.clientSessionId == summary.clientSessionId,
    );
    if (matching.length != 1 || matching.single.repetitions != 2) {
      throw StateError('History does not contain exactly one matching summary');
    }
    stdout.writeln(
      'PASS real HTTP: login, assignment, simulated save, identical retry, '
      'conflict rejection and server history.',
    );
  } on ApiException catch (error) {
    stderr.writeln('FAIL ${error.code}: ${error.message}');
    exitCode = 1;
  } catch (error) {
    stderr.writeln('FAIL API smoke: ${error.runtimeType}');
    exitCode = 1;
  } finally {
    api.close();
  }
}
