import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:restora_frontend/core/api/api_client.dart';
import 'package:restora_frontend/core/platform/token_store.dart';
import 'package:restora_frontend/features/authentication/data/auth_repository.dart';
import 'package:restora_frontend/features/authentication/screens/login_screen.dart';
import 'package:restora_frontend/features/authentication/state/auth_controller.dart';

class TestTokenStore implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets(
    'leaving pending reauthentication does not access a disposed password field',
    (tester) async {
      final response = Completer<http.Response>();
      final api = ApiClient(
        baseUrl: Uri.parse('https://api.example.test'),
        token: () => null,
        client: MockClient((_) => response.future),
      );
      final auth = AuthController(AuthRepository(api), TestTokenStore());
      addTearDown(() {
        auth.dispose();
        api.close();
      });
      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(controller: auth, reauthenticate: true)),
      );
      await tester.enterText(find.byType(TextField).last, 'entered-password');
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(auth.busy, true);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      final claims = base64Url.encode(utf8.encode('{"sub":"account-a"}'));
      response.complete(
        http.Response(
          jsonEncode({
            'access_token': 'header.$claims.signature',
            'token_type': 'bearer',
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(auth.token, isNotNull);
    },
  );
}
