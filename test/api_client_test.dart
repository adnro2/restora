import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:restora_frontend/core/api/api_client.dart';
import 'package:restora_frontend/core/api/api_exception.dart';
import 'package:restora_frontend/features/authentication/data/auth_repository.dart';
import 'package:restora_frontend/features/sessions/data/session_repository.dart';
import 'package:restora_frontend/features/sessions/data/session_summary.dart';

void main() {
  ApiClient apiWith(
    Future<http.Response> Function(http.Request) handle, {
    String? token = 'test-token',
    Duration timeout = const Duration(seconds: 15),
  }) => ApiClient(
    baseUrl: Uri.parse('https://api.example.test'),
    token: () => token,
    timeout: timeout,
    client: MockClient(handle),
  );

  test(
    'login sends JSON credentials without authorization and reads token',
    () async {
      final api = apiWith((request) async {
        expect(request.url.path, '/v1/auth/login');
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {
          'email': 'demo@example.test',
          'password': 'entered-password',
        });
        return http.Response(
          '{"access_token":"issued","token_type":"bearer","expires_in":3600}',
          200,
        );
      });
      addTearDown(api.close);
      expect(
        await AuthRepository(
          api,
        ).login(' demo@example.test ', 'entered-password'),
        'issued',
      );
    },
  );

  test(
    'sends frozen session body, bearer token and parses created record',
    () async {
      final summary = SessionSummary(
        clientSessionId: 'client-uuid',
        assignmentId: 'assignment-uuid',
        exerciseId: 'elbow_flexion_extension',
        startedAt: DateTime.utc(2026, 10, 16),
        endedAt: DateTime.utc(2026, 10, 16, 0, 1),
        completedRepetitions: 2,
        trackingMode: 'simulated',
        stopReason: 'user_stopped',
      );
      final api = apiWith((request) async {
        expect(request.url.path, '/v1/sessions');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), summary.toJson());
        return http.Response(
          jsonEncode({
            ...summary.toJson(),
            'id': 'saved-uuid',
            'created_at': '2026-10-16T00:01:01Z',
          }),
          201,
        );
      });
      addTearDown(api.close);
      final saved = await ApiSessionRepository(api).save(summary);
      expect(saved.clientSessionId, summary.clientSessionId);
      expect(saved.repetitions, 2);
    },
  );

  test('maps authentication, validation and conflict envelopes', () async {
    for (final status in [401, 422, 409]) {
      final api = apiWith(
        (_) async => http.Response(
          '{"error":{"code":"test_$status","message":"Actionable message"}}',
          status,
        ),
      );
      await expectLater(
        api.get('/v1/sessions'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'test_$status')
              .having((e) => e.message, 'message', 'Actionable message')
              .having((e) => e.statusCode, 'status', status),
        ),
      );
      api.close();
    }
  });

  test(
    'proxy HTML and malformed successful JSON produce understandable errors',
    () async {
      final unavailable = apiWith(
        (_) async => http.Response('<html>proxy error</html>', 503),
      );
      final malformed = apiWith((_) async => http.Response('{not-json', 200));
      addTearDown(unavailable.close);
      addTearDown(malformed.close);
      await expectLater(
        unavailable.get('/v1/sessions'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('server'),
          ),
        ),
      );
      await expectLater(
        malformed.get('/v1/sessions'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    },
  );

  test(
    'malformed model shape is an API error rather than a cast exception',
    () async {
      final api = apiWith(
        (_) async => http.Response('{"items":[{"id":1}]}', 200),
      );
      addTearDown(api.close);
      await expectLater(
        ApiSessionRepository(api).history(),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'invalid_response'),
        ),
      );
    },
  );

  test('network and timeout failures are mapped', () async {
    final network = apiWith(
      (_) async => throw http.ClientException('no connection'),
    );
    final timeout = apiWith(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 1),
    );
    addTearDown(network.close);
    addTearDown(timeout.close);
    await expectLater(
      network.get('/v1/sessions'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'network_error'),
      ),
    );
    await expectLater(
      timeout.get('/v1/sessions'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'timeout')),
    );
  });

  test('no token prevents an authenticated request', () async {
    final api = apiWith(
      (_) async => fail('Must not send unauthenticated request'),
      token: null,
    );
    addTearDown(api.close);
    await expectLater(
      api.get('/v1/sessions'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isUnauthorized,
          'unauthorized',
          true,
        ),
      ),
    );
  });

  test('rejects nonlocal cleartext API endpoints', () {
    expect(
      () => ApiClient(
        baseUrl: Uri.parse('http://public.example.test'),
        token: () => null,
      ),
      throwsArgumentError,
    );
  });

  test('release configuration rejects local HTTP as well', () {
    expect(
      () => ApiClient(
        baseUrl: Uri.parse('http://127.0.0.1:8000'),
        token: () => null,
        allowLocalHttp: false,
      ),
      throwsArgumentError,
    );
  });
}
