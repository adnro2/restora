import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import 'core/api/api_client.dart';
import 'core/platform/token_store.dart';
import 'core/ui/restora_theme.dart';
import 'core/ui/restora_widgets.dart';
import 'features/authentication/data/auth_repository.dart';
import 'features/authentication/screens/login_screen.dart';
import 'features/authentication/state/auth_controller.dart';
import 'features/exercise/screens/assignment_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RestoraApp());
}

class RestoraApp extends StatefulWidget {
  const RestoraApp({super.key});

  @override
  State<RestoraApp> createState() => _RestoraAppState();
}

class _RestoraAppState extends State<RestoraApp> {
  late final ApiClient _api;
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    const base = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    );
    _api = ApiClient(
      baseUrl: Uri.parse(base),
      token: () => _auth.token,
      allowLocalHttp: kDebugMode,
    );
    _auth = AuthController(AuthRepository(_api), SecureTokenStore());
    unawaited(_auth.restore());
  }

  @override
  void dispose() {
    _auth.dispose();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Restora Demo',
    debugShowCheckedModeBanner: false,
    theme: RestoraTheme.light,
    home: ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        if (_auth.restoring) {
          return const Scaffold(
            body: PageBody(
              children: [
                SizedBox(height: 56),
                StatePanel(
                  icon: Icons.lock_outline_rounded,
                  title: 'Opening Restora',
                  message: 'Checking your sign-in securely.',
                  loading: true,
                ),
              ],
            ),
          );
        }
        return _auth.token == null
            ? LoginScreen(controller: _auth)
            : AssignmentScreen(api: _api, auth: _auth);
      },
    ),
  );
}
