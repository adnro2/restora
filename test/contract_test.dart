import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:restora_frontend/core/api/api_client.dart';
import 'package:restora_frontend/features/exercise/data/assignment.dart';
import 'package:restora_frontend/features/sessions/data/session_repository.dart';
import 'package:restora_frontend/features/sessions/data/session_summary.dart';

void main() {
  final contract =
      jsonDecode(File('contract/openapi.json').readAsStringSync())
          as Map<String, dynamic>;
  final schemas =
      (contract['components'] as Map<String, dynamic>)['schemas']
          as Map<String, dynamic>;
  final example =
      jsonDecode(File('contract/session.example.json').readAsStringSync())
          as Map<String, dynamic>;

  test(
    'approved session example serializes against backend-required fields and enums',
    () async {
      final schema = schemas['SessionCreate'] as Map<String, dynamic>;
      final properties = schema['properties'] as Map<String, dynamic>;
      final paths = contract['paths'] as Map<String, dynamic>;
      final operation =
          (paths['/v1/sessions'] as Map<String, dynamic>)['post']
              as Map<String, dynamic>;
      final request = operation['requestBody'] as Map<String, dynamic>;
      final content = request['content'] as Map<String, dynamic>;
      final media = content['application/json'] as Map<String, dynamic>;
      expect(media['schema'], {r'$ref': '#/components/schemas/SessionCreate'});

      final summary = SessionSummary(
        clientSessionId: example['client_session_id'] as String,
        assignmentId: example['assignment_id'] as String,
        exerciseId: example['exercise_id'] as String,
        startedAt: DateTime.parse(example['started_at'] as String),
        endedAt: DateTime.parse(example['ended_at'] as String),
        completedRepetitions: example['completed_repetitions'] as int,
        trackingMode: example['tracking_mode'] as String,
        stopReason: example['stop_reason'] as String,
      );
      final payload = summary.toJson();
      expect(
        payload.keys.toSet(),
        (schema['required'] as List<dynamic>).toSet(),
      );
      expect(payload.keys.toSet(), example.keys.toSet());
      for (final field in ['client_session_id', 'assignment_id']) {
        expect((properties[field] as Map<String, dynamic>)['format'], 'uuid');
      }
      for (final field in ['started_at', 'ended_at']) {
        expect(
          (properties[field] as Map<String, dynamic>)['format'],
          'date-time',
        );
        expect(
          DateTime.parse(payload[field] as String),
          DateTime.parse(example[field] as String),
        );
      }
      for (final field in ['tracking_mode', 'stop_reason']) {
        expect(
          (properties[field] as Map<String, dynamic>)['enum'],
          contains(payload[field]),
        );
      }
      expect((properties['tracking_mode'] as Map<String, dynamic>)['enum'], [
        'simulated',
        'camera',
      ]);
      expect((properties['stop_reason'] as Map<String, dynamic>)['enum'], [
        'user_stopped',
        'tracking_lost',
        'app_inactive',
      ]);
      expect(
        (properties['exercise_id'] as Map<String, dynamic>)['const'],
        payload['exercise_id'],
      );

      final api = ApiClient(
        baseUrl: Uri.parse('https://api.example.test'),
        token: () => 'token',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/sessions');
          final received = jsonDecode(request.body) as Map<String, dynamic>;
          for (final key in example.keys.where(
            (key) => key != 'started_at' && key != 'ended_at',
          )) {
            expect(received[key], example[key]);
          }
          return http.Response(
            jsonEncode({
              ...received,
              'id': '44444444-4444-4444-8444-444444444444',
              'created_at': '2026-10-16T02:01:01Z',
            }),
            201,
          );
        }),
      );
      addTearDown(api.close);
      final saved = await ApiSessionRepository(api).save(summary);
      expect(saved.clientSessionId, example['client_session_id']);
      expect(saved.repetitions, example['completed_repetitions']);
      expect(saved.trackingMode, 'simulated');
    },
  );

  test('consumer accepts approved assignment defaults and review labels', () {
    final schema = schemas['AssignmentResponse'] as Map<String, dynamic>;
    final properties = schema['properties'] as Map<String, dynamic>;
    final response = <String, dynamic>{
      'id': example['assignment_id'],
      'exercise_id':
          (properties['exercise_id'] as Map<String, dynamic>)['const'],
      for (final entry in properties.entries)
        if ((entry.value as Map<String, dynamic>).containsKey('default'))
          entry.key: (entry.value as Map<String, dynamic>)['default'],
    };
    final assignment = Assignment.fromJson(response);
    expect(assignment.exerciseId, 'elbow_flexion_extension');
    expect(assignment.flexedThreshold, 70);
    expect(assignment.extendedThreshold, 150);
    expect(assignment.targetRepetitions, 10);
    expect(
      assignment.instructions.join(' ').toLowerCase(),
      contains('professional review'),
    );
    expect(response['demonstration_only'], true);
    expect(response['professional_review_required'], true);
  });
}
