import 'dart:async';

import 'package:flutter/material.dart';

import '../../authentication/screens/login_screen.dart';
import '../../authentication/state/auth_controller.dart';
import '../data/session_repository.dart';
import '../state/history_controller.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.repository,
    required this.auth,
    super.key,
  });
  final SessionRepository repository;
  final AuthController auth;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final _controller = HistoryController(widget.repository);

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Session history')),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _controller.load,
          child: ListView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const Text('Your saved sessions.'),
              const SizedBox(height: 16),
              if (_controller.error case final message?) ...[
                Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _controller.load,
                  child: const Text('Retry history'),
                ),
                TextButton(
                  onPressed: () async {
                    if (await reauthenticate(context, widget.auth)) {
                      await _controller.load();
                    }
                  },
                  child: const Text('Sign in again'),
                ),
              ],
              if (_controller.sessions.isEmpty && _controller.error == null)
                const Text(
                  'No sessions yet. Stop and save a demo session to see it here.',
                ),
              for (final session in _controller.sessions)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.accessibility_new),
                    title: Text('${session.repetitions} complete repetitions'),
                    subtitle: Text(
                      '${session.startedAt.toLocal()}\n'
                      '${session.trackingMode.toUpperCase()} · ${session.stopReason.replaceAll('_', ' ')}',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
