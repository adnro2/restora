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
import 'package:restora_frontend/features/authentication/state/auth_controller.dart';
import 'package:restora_frontend/features/exercise/screens/assignment_screen.dart';
import 'package:restora_frontend/features/exercise/screens/exercise_screen.dart';
import 'package:restora_frontend/features/sessions/screens/history_screen.dart';

import 'support/ux_fixtures.dart';

class _GatedTokenStore implements TokenStore {
  final clearResult = Completer<void>();
  var clearCalls = 0;

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() {
    clearCalls++;
    return clearResult.future;
  }
}

class _NavigationObserver extends NavigatorObserver {
  var pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  testWidgets(
    'sign-out blocks navigation until secure storage responds and recovers on failure',
    (tester) async {
      final store = _GatedTokenStore();
      final observer = _NavigationObserver();
      late final AuthController auth;
      final api = ApiClient(
        baseUrl: Uri.parse('https://api.example.test'),
        token: () => auth.token,
        client: MockClient((request) async {
          if (request.url.path == '/v1/assignment') {
            return http.Response(jsonEncode(assignmentPayload()), 200);
          }
          if (request.url.path == '/v1/sessions') {
            return http.Response('{"items":[]}', 200);
          }
          fail('Unexpected request: ${request.url.path}');
        }),
      );
      auth = AuthController(AuthRepository(api), store)
        ..token = 'synthetic-access-token';
      addTearDown(() {
        auth.dispose();
        api.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: RestoraTheme.light,
          navigatorObservers: [observer],
          home: AssignmentScreen(api: api, auth: auth),
        ),
      );
      await tester.pumpAndSettle();
      final initialPushes = observer.pushes;
      final historyButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Session history',
      );
      final signOutButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Sign out',
      );
      final sessionButton = find.widgetWithText(
        FilledButton,
        'Open simulated session',
      );
      final lowerHistoryButton = find.widgetWithText(
        OutlinedButton,
        'View session history',
      );

      // Retain callbacks from the preceding frame to cover a click arriving
      // before the disabled controls have rebuilt.
      final openHistory = tester.widget<IconButton>(historyButton).onPressed!;
      await tester.scrollUntilVisible(sessionButton, 200);
      final openSession = tester.widget<FilledButton>(sessionButton).onPressed!;
      await tester.scrollUntilVisible(lowerHistoryButton, 200);
      final openLowerHistory = tester
          .widget<OutlinedButton>(lowerHistoryButton)
          .onPressed!;
      await tester.tap(signOutButton);
      openHistory();
      openSession();
      openLowerHistory();
      await tester.pump();

      expect(store.clearCalls, 1);
      expect(auth.token, 'synthetic-access-token');
      expect(observer.pushes, initialPushes);
      expect(find.byType(HistoryScreen), findsNothing);
      expect(find.byType(ExerciseScreen), findsNothing);
      expect(tester.widget<IconButton>(historyButton).onPressed, isNull);
      expect(tester.widget<IconButton>(signOutButton).onPressed, isNull);
      expect(
        tester.widget<OutlinedButton>(lowerHistoryButton).onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(sessionButton, -200);
      expect(tester.widget<FilledButton>(sessionButton).onPressed, isNull);

      store.clearResult.completeError(StateError('Synthetic storage failure'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Could not sign out'), -200);
      expect(find.text('Could not sign out'), findsOneWidget);
      expect(auth.token, 'synthetic-access-token');
      expect(tester.widget<IconButton>(historyButton).onPressed, isNotNull);
      expect(tester.widget<IconButton>(signOutButton).onPressed, isNotNull);
      await tester.scrollUntilVisible(sessionButton, 200);
      expect(tester.widget<FilledButton>(sessionButton).onPressed, isNotNull);
      await tester.scrollUntilVisible(lowerHistoryButton, 200);
      expect(
        tester.widget<OutlinedButton>(lowerHistoryButton).onPressed,
        isNotNull,
      );
      await tester.tap(historyButton);
      await tester.pumpAndSettle();
      expect(observer.pushes, initialPushes + 1);
      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
