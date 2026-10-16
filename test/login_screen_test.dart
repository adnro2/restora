import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:restora_frontend/core/api/api_client.dart';
import 'package:restora_frontend/core/platform/token_store.dart';
import 'package:restora_frontend/core/ui/restora_theme.dart';
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
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign in'));
      await tester.pumpAndSettle();
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

  testWidgets('invalid fields stay local and recover as details are corrected', (
    tester,
  ) async {
    var requests = 0;
    final api = ApiClient(
      baseUrl: Uri.parse('https://api.example.test'),
      token: () => null,
      client: MockClient((_) async {
        requests++;
        return http.Response(
          '{"error":{"code":"invalid_credentials","message":"Check your email and password."}}',
          401,
        );
      }),
    );
    final auth = AuthController(AuthRepository(api), TestTokenStore());
    addTearDown(() {
      auth.dispose();
      api.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: RestoraTheme.light,
        home: LoginScreen(controller: auth),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'invalid');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(requests, 0);

    await tester.enterText(find.byType(TextField).first, 'demo@example.test');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).focusNode!.hasFocus,
      true,
    );
    await tester.enterText(find.byType(TextField).last, 'entered-password');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsNothing);
    expect(find.text('Enter your password.'), findsNothing);
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('Check your email and password.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsWidgets,
    );
    await tester.enterText(find.byType(TextField).last, 'corrected-password');
    await tester.pump();
    expect(find.text('Check your email and password.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small screen and larger text keep sign-in usable during request',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var requests = 0;
      final response = Completer<http.Response>();
      final api = ApiClient(
        baseUrl: Uri.parse('https://api.example.test'),
        token: () => null,
        client: MockClient((_) {
          requests++;
          return response.future;
        }),
      );
      final auth = AuthController(AuthRepository(api), TestTokenStore());
      addTearDown(() {
        auth.dispose();
        api.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: RestoraTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: LoginScreen(controller: auth),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('login-password')),
        200,
      );
      await tester.enterText(find.byType(TextField).last, 'entered-password');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        false,
      );
      expect(find.byTooltip('Hide password'), findsOneWidget);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(requests, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.enabled, false);
      }
      expect(find.text('Signing in…'), findsOneWidget);
      expect(tester.takeException(), isNull);
      response.complete(
        http.Response(
          '{"error":{"code":"unavailable","message":"Please try again."}}',
          503,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Please try again.'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
