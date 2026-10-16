import 'package:flutter/material.dart';

import '../../../core/ui/restora_widgets.dart';
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
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _passwordVisible = false;
  bool _showServerError = true;
  String? _emailError;
  String? _passwordError;

  String? _validateEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
      ? null
      : 'Enter a valid email address.';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.controller.busy) return;
    setState(() {
      _emailError = _validateEmail(_email.text);
      _passwordError = _password.text.isEmpty ? 'Enter your password.' : null;
      _showServerError = _emailError == null && _passwordError == null;
    });
    if (_emailError != null) {
      _emailFocus.requestFocus();
      return;
    }
    if (_passwordError != null) {
      _passwordFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
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
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final busy = widget.controller.busy;
        return PageBody(
          children: [
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.self_improvement_rounded,
                  size: 40,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.reauthenticate
                  ? 'Welcome back'
                  : 'Your movement, one step at a time.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              widget.reauthenticate
                  ? 'Sign in with the same account to continue where you left off.'
                  : 'Sign in to see your assigned exercise and saved sessions.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            const StatusNotice(
              title: 'Online demonstration',
              message:
                  'For synthetic demo accounts only. An internet connection is required.',
              icon: Icons.science_outlined,
            ),
            const SizedBox(height: 24),
            SectionCard(
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Account details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text('Use your Restora demo account details.'),
                    const SizedBox(height: 24),
                    TextField(
                      key: const ValueKey('login-email'),
                      controller: _email,
                      focusNode: _emailFocus,
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.mail_outline),
                        errorText: _emailError,
                        errorMaxLines: 3,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username],
                      onChanged: (_) => setState(() {
                        _showServerError = false;
                        if (_emailError != null) {
                          _emailError = _validateEmail(_email.text);
                        }
                      }),
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      key: const ValueKey('login-password'),
                      controller: _password,
                      focusNode: _passwordFocus,
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText: 'Demo account password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _passwordVisible
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: busy
                              ? null
                              : () => setState(
                                  () => _passwordVisible = !_passwordVisible,
                                ),
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                        errorText: _passwordError,
                        errorMaxLines: 3,
                      ),
                      obscureText: !_passwordVisible,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onChanged: (_) => setState(() {
                        _showServerError = false;
                        if (_passwordError != null) {
                          _passwordError = _password.text.isEmpty
                              ? 'Enter your password.'
                              : null;
                        }
                      }),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_showServerError)
                      if (widget.controller.error case final message?) ...[
                        const SizedBox(height: 20),
                        Semantics(
                          liveRegion: true,
                          child: StatusNotice(
                            title: 'Could not sign in',
                            message: message,
                            icon: Icons.error_outline,
                            tone: NoticeTone.error,
                          ),
                        ),
                      ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (busy) ...[
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Flexible(
                              child: Text(busy ? 'Signing in…' : 'Sign in'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Movement instructions and exercise defaults require professional review before patient use.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
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
