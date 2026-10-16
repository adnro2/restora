import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:restora_frontend/core/api/api_exception.dart';
import 'package:restora_frontend/core/ui/restora_theme.dart';
import 'package:restora_frontend/features/authentication/screens/login_screen.dart';
import 'package:restora_frontend/features/exercise/platform/simulated_pose_source.dart';
import 'package:restora_frontend/features/exercise/screens/assignment_screen.dart';
import 'package:restora_frontend/features/exercise/screens/exercise_screen.dart';
import 'package:restora_frontend/features/exercise/state/exercise_controller.dart';
import 'package:restora_frontend/features/sessions/screens/history_screen.dart';

import 'support/ux_fixtures.dart';

Widget app(Widget screen, {double textScale = 1}) => MaterialApp(
  theme: RestoraTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: screen,
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: scrollables.first,
      maxScrolls: 30,
    );
  }
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'assignment loading and network retry keep the account signed in',
    (tester) async {
      final response = Completer<http.Response>();
      var requests = 0;
      final fixture = UxFixture(
        handle: (_) async {
          requests++;
          if (requests == 1) return response.future;
          return http.Response(jsonEncode(assignmentPayload()), 200);
        },
      );
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        app(AssignmentScreen(api: fixture.api, auth: fixture.auth)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      response.completeError(http.ClientException('connection unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Check your internet connection'),
        findsOneWidget,
      );
      expect(find.text('Sign in again'), findsNothing);
      await tapVisible(tester, find.text('Retry assignment'));
      expect(requests, 2);
      expect(find.text(uxAssignment.title), findsOneWidget);
      expect(find.text('Open simulated session'), findsOneWidget);
      expect(fixture.auth.token, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an expired assignment token offers in-place sign in', (
    tester,
  ) async {
    final fixture = UxFixture(
      handle: (_) async => http.Response(
        '{"error":{"code":"unauthorized","message":"Your sign-in expired. Sign in again, then retry."}}',
        401,
      ),
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      app(AssignmentScreen(api: fixture.api, auth: fixture.auth)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open simulated session'), findsNothing);
    await tapVisible(tester, find.text('Sign in again'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed save keeps a stopped session through Back and identical retry',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = UxFixture();
      addTearDown(fixture.dispose);
      final source = UxPoseSource();
      final sessions = UxSessions()
        ..failure = const ApiException(
          'network_error',
          'Cannot connect. Check your internet connection and retry.',
        );
      var now = DateTime.utc(2026, 10, 16, 8);
      final controller = ExerciseController(
        assignment: uxAssignment,
        source: source,
        sessions: sessions,
        now: () => now,
        newId: () => 'frozen-client-session',
      );
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ExerciseScreen(
                      controller: controller,
                      auth: fixture.auth,
                    ),
                  ),
                ),
                child: const Text('Open test session'),
              ),
            ),
          ),
          textScale: 1.5,
        ),
      );
      await tapVisible(tester, find.text('Open test session'));
      expect(find.textContaining('NO CAMERA TRACKING'), findsOneWidget);
      await tapVisible(tester, find.text('Start simulated session'));
      expect(controller.running, isTrue);
      source.completeCycle();
      now = now.add(const Duration(seconds: 3));
      await tester.pump();
      expect(controller.counter.repetitions, 1);
      await tapVisible(tester, find.text('Stop and save'));
      // Stream cancellation finishes on the real event loop, before saving.
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(controller.running, isFalse);
      expect(controller.pending, isNotNull);
      expect(sessions.submissions, hasLength(1));
      final frozen = jsonEncode(sessions.submissions.single.toJson());
      expect(controller.running, false);
      expect(controller.pending!.completedRepetitions, 1);
      expect(find.text('Start simulated session'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseScreen), findsOneWidget);
      expect(jsonEncode(controller.pending!.toJson()), frozen);
      sessions.failure = null;
      now = now.add(const Duration(hours: 1));
      await tapVisible(tester, find.text('Retry save'));
      expect(sessions.submissions, hasLength(2));
      expect(jsonEncode(sessions.submissions.last.toJson()), frozen);
      expect(controller.saved!.clientSessionId, 'frozen-client-session');
      expect(find.text('Retry save'), findsNothing);
      await tapVisible(tester, find.text('Done'));
      expect(find.byType(ExerciseScreen), findsNothing);
      expect(find.text('Open test session'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('primary screens fit a 360px phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = UxFixture();
    addTearDown(fixture.dispose);
    final pages = <Widget Function()>[
      () => LoginScreen(controller: fixture.auth),
      () => AssignmentScreen(api: fixture.api, auth: fixture.auth),
      () => ExerciseScreen(
        controller: ExerciseController(
          assignment: uxAssignment,
          source: SimulatedPoseSource(),
          sessions: UxSessions(),
        ),
        auth: fixture.auth,
      ),
      () => HistoryScreen(repository: UxSessions(), auth: fixture.auth),
    ];
    for (final page in pages) {
      await tester.pumpWidget(app(page(), textScale: 1.5));
      await tester.pumpAndSettle();
      final scrollables = find.byType(Scrollable);
      expect(scrollables, findsWidgets);
      await tester.drag(scrollables.first, const Offset(0, -1600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
