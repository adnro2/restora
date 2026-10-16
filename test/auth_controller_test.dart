import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:restora_frontend/core/api/api_client.dart';
import 'package:restora_frontend/core/platform/token_store.dart';
import 'package:restora_frontend/features/authentication/data/auth_repository.dart';
import 'package:restora_frontend/features/authentication/state/auth_controller.dart';

class MemoryTokenStore implements TokenStore {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async {
    if (failWrite) throw Exception('Keystore unavailable');
    value = token;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  late ApiClient api;
  late AuthController controller;
  late MemoryTokenStore store;
  var calls = 0;
  var issuedSubject = 'account-a';
  String jwt(String subject) =>
      'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': subject})))}.signature';

  setUp(() {
    calls = 0;
    issuedSubject = 'account-a';
    store = MemoryTokenStore();
    api = ApiClient(
      baseUrl: Uri.parse('https://api.example.test'),
      token: () => null,
      client: MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'access_token': jwt(issuedSubject),
            'token_type': 'bearer',
          }),
          200,
        );
      }),
    );
    controller = AuthController(AuthRepository(api), store);
  });
  tearDown(() {
    controller.dispose();
    api.close();
  });

  test('validates missing credentials before sending request', () async {
    expect(await controller.login('invalid', ''), false);
    expect(calls, 0);
    expect(controller.error, 'Enter your email and password.');
  });

  test(
    'restores token and persists successful login only through token store',
    () async {
      store.value = jwt('account-a');
      await controller.restore();
      expect(controller.restoring, false);
      expect(controller.token, jwt('account-a'));
      expect(
        await controller.login('demo@example.test', 'entered-password'),
        true,
      );
      expect(controller.token, jwt('account-a'));
      expect(store.value, jwt('account-a'));
      await controller.logout();
      expect(controller.token, isNull);
      expect(store.value, isNull);
    },
  );

  test(
    'secure storage write failure does not leave an authenticated UI',
    () async {
      store.failWrite = true;
      expect(
        await controller.login('demo@example.test', 'entered-password'),
        false,
      );
      expect(controller.token, isNull);
      expect(controller.error, contains('securely store'));
      expect(controller.busy, false);
    },
  );

  test(
    'in-place reauthentication rejects another account before replacing storage',
    () async {
      store.value = jwt('account-a');
      await controller.restore();
      issuedSubject = 'account-b';
      expect(
        await controller.login('other@example.test', 'entered-password'),
        false,
      );
      expect(controller.token, jwt('account-a'));
      expect(store.value, jwt('account-a'));
      expect(controller.error, contains('original account'));
      // An intentional signout removes feature state before the next account signs in.
      await controller.logout();
      expect(
        await controller.login('other@example.test', 'entered-password'),
        true,
      );
      expect(controller.token, jwt('account-b'));
    },
  );
}
