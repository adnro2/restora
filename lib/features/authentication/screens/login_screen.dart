import 'package:flutter/material.dart';

import '../state/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.controller,
    this.reauthenticate = false,
    super.key,
  });
  final AuthController controller;
  final bool reauthenticate;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'demo@example.test');
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await widget.controller.login(_email.text, _password.text);
    if (!mounted) return;
    if (success) _password.clear();
    if (success && widget.reauthenticate) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.reauthenticate ? 'Sign in again' : 'Restora'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              Text(
                'Home rehabilitation companion',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Engineering demonstration · synthetic accounts only. Online connection required.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                enabled: !widget.controller.busy,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.username],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                enabled: !widget.controller.busy,
                decoration: const InputDecoration(
                  labelText: 'Demo account password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) {
                  if (!widget.controller.busy) _submit();
                },
              ),
              if (widget.controller.error case final message?) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  semanticsLabel: 'Sign in error: $message',
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: widget.controller.busy ? null : _submit,
                child: Text(widget.controller.busy ? 'Signing in…' : 'Sign in'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Use the password set when Developer B seeds the backend. No password is bundled in this app.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> reauthenticate(BuildContext context, AuthController auth) async =>
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => LoginScreen(controller: auth, reauthenticate: true),
      ),
    ) ??
    false;
