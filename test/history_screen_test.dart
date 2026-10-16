import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:restora_frontend/core/api/api_client.dart';
import 'package:restora_frontend/core/api/api_exception.dart';
import 'package:restora_frontend/core/platform/token_store.dart';
import 'package:restora_frontend/core/ui/restora_theme.dart';
import 'package:restora_frontend/features/authentication/data/auth_repository.dart';
import 'package:restora_frontend/features/authentication/state/auth_controller.dart';
import 'package:restora_frontend/features/sessions/data/session_repository.dart';
import 'package:restora_frontend/features/sessions/data/session_summary.dart';
import 'package:restora_frontend/features/sessions/screens/history_screen.dart';
import 'package:restora_frontend/features/sessions/state/history_controller.dart';

class _TestTokenStore implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

class _Sessions implements SessionRepository {
  _Sessions(this.load);
  final Future<List<SavedSession>> Function() load;
  @override
  Future<List<SavedSession>> history() => load();
  @override
  Future<SavedSession> save(SessionSummary summary) =>
      throw UnimplementedError('History screen must not save sessions.');
}

void main() {
  late ApiClient api;
  late AuthController auth;

  setUp(() {
    api = ApiClient(
      baseUrl: Uri.parse('https://api.example.test'),
      token: () => null,
      client: MockClient((_) async => http.Response('{}', 500)),
    );
    auth = AuthController(AuthRepository(api), _TestTokenStore());
  });

  tearDown(() {
    auth.dispose();
    api.close();
  });

  Widget app(SessionRepository repository, {double textScale = 1}) =>
      MaterialApp(
        theme: RestoraTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: HistoryScreen(repository: repository, auth: auth),
      );

  SavedSession session({
    String mode = 'simulated',
    String reason = 'user_stopped',
  }) => SavedSession(
    id: 'saved-session',
    clientSessionId: 'client-session',
    repetitions: 4,
    startedAt: DateTime(2026, 10, 16, 14, 5),
    trackingMode: mode,
    stopReason: reason,
  );

  testWidgets(
    'loading becomes empty and refresh fetches readable saved sessions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final first = Completer<List<SavedSession>>();
      var requests = 0;
      final repository = _Sessions(() {
        requests++;
        return requests == 1 ? first.future : Future.value([session()]);
      });
      await tester.pumpWidget(app(repository));
      await tester.pump();
      expect(find.text('Loading your sessions…'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Loading session history')),
        findsWidgets,
      );
      semantics.dispose();
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      first.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('Your first session starts here'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh history'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.text('4 complete repetitions'), findsOneWidget);
      expect(find.text('SIMULATED'), findsOneWidget);
      expect(find.text('Stopped by you'), findsOneWidget);
      expect(find.textContaining('Oct 16, 2026'), findsOneWidget);
      expect(find.textContaining('2:05 PM'), findsOneWidget);
      expect(find.textContaining('00.000'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('network failures offer retry without asking for sign in', (
    tester,
  ) async {
    var requests = 0;
    final repository = _Sessions(() async {
      requests++;
      if (requests == 1) {
        throw const ApiException('network_error', 'Check your connection.');
      }
      return [];
    });
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    expect(find.text('Check your connection.'), findsOneWidget);
    expect(find.text('Sign in again'), findsNothing);
    await tester.ensureVisible(find.text('Retry history'));
    await tester.tap(find.text('Retry history'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Your first session starts here'), findsOneWidget);
  });

  testWidgets('expired authentication offers same-account sign in', (
    tester,
  ) async {
    final repository = _Sessions(() async {
      throw const ApiException(
        'expired_token',
        'Sign in again to continue.',
        statusCode: 401,
      );
    });
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to see your history'), findsOneWidget);
    expect(find.text('Retry history'), findsNothing);
    await tester.ensureVisible(find.text('Sign in again'));
    await tester.tap(find.text('Sign in again'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      find.text(
        'Sign in with the same account to continue where you left off.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'camera history remains readable on narrow screens with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          _Sessions(
            () async => [session(mode: 'camera', reason: 'app_inactive')],
          ),
          textScale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('CAMERA'), 200);
      expect(find.text('4 complete repetitions'), findsOneWidget);
      expect(find.text('CAMERA'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Stopped when the app left the foreground'),
      );
      expect(
        find.text('Stopped when the app left the foreground'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'refresh clears cached rows and classifies authentication failure',
    () async {
      var requests = 0;
      final controller = HistoryController(
        _Sessions(() async {
          requests++;
          if (requests == 1) return [session()];
          if (requests == 2) {
            throw const ApiException(
              'expired_token',
              'Sign in again.',
              statusCode: 401,
            );
          }
          throw const ApiException('network_error', 'Cannot connect.');
        }),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.sessions, hasLength(1));
      await controller.load();
      expect(controller.sessions, isEmpty);
      expect(controller.authenticationRequired, true);
      await controller.load();
      expect(controller.authenticationRequired, false);
      expect(controller.sessions, isEmpty);
    },
  );
}
