import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restora_frontend/core/ui/restora_theme.dart';
import 'package:restora_frontend/features/authentication/screens/login_screen.dart';
import 'package:restora_frontend/features/exercise/platform/simulated_pose_source.dart';
import 'package:restora_frontend/features/exercise/screens/assignment_screen.dart';
import 'package:restora_frontend/features/exercise/screens/exercise_screen.dart';
import 'package:restora_frontend/features/exercise/state/exercise_controller.dart';
import 'package:restora_frontend/features/sessions/screens/history_screen.dart';

import 'support/ux_fixtures.dart';

const _writePreviews = bool.fromEnvironment('WRITE_UI_PREVIEWS');

/// Optional review artifacts of real widgets, not camera or device evidence.
/// flutter test test/ui_preview_test.dart --dart-define=WRITE_UI_PREVIEWS=true
void main() {
  testWidgets('write synthetic 390px Flutter UI previews for visual review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final flutterRoot =
        Platform.environment['FLUTTER_ROOT'] ?? '../.tools/flutter';
    final fonts = Directory('$flutterRoot/bin/cache/artifacts/material_fonts');
    final loader = FontLoader('Roboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      final file = File('${fonts.path}/roboto-$weight.ttf');
      if (!file.existsSync()) {
        throw StateError('Flutter SDK font missing: ${file.path}');
      }
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('${fonts.path}/materialicons-regular.otf').readAsBytesSync(),
          ),
        ),
      );
    await icons.load();

    final fixture = UxFixture();
    addTearDown(fixture.dispose);
    final pages = <String, Widget Function()>{
      'login': () => LoginScreen(controller: fixture.auth),
      'assignment': () =>
          AssignmentScreen(api: fixture.api, auth: fixture.auth),
      'exercise_simulated': () => ExerciseScreen(
        controller: ExerciseController(
          assignment: uxAssignment,
          source: SimulatedPoseSource(),
          sessions: UxSessions(),
        ),
        auth: fixture.auth,
      ),
      'history': () =>
          HistoryScreen(repository: UxSessions(), auth: fixture.auth),
    };
    final output = Directory('build/ux_previews')..createSync(recursive: true);
    // Android normally resolves unspecified families to Roboto; Flutter's
    // test engine uses Ahem. Specify that same Android family for previews.
    final theme = RestoraTheme.light;
    final previewTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Roboto'),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: 'Roboto',
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: theme.filledButtonTheme.style?.copyWith(
          textStyle: WidgetStateProperty.resolveWith(
            (states) => theme.filledButtonTheme.style?.textStyle
                ?.resolve(states)
                ?.copyWith(fontFamily: 'Roboto'),
          ),
        ),
      ),
    );
    for (final entry in pages.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: previewTheme,
            home: entry.value(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('${output.path}/${entry.key}.png').writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        image.dispose();
      });
    }
    File('${output.path}/README.txt').writeAsStringSync(
      'Flutter widget-test renders at 390 x 1000 logical pixels.\n'
      'Synthetic fixtures only. These are not Android-phone screenshots and do not verify camera tracking.\n'
      'Regenerate: flutter test test/ui_preview_test.dart --dart-define=WRITE_UI_PREVIEWS=true\n',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !_writePreviews);
}
