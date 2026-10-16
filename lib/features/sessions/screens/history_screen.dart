import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/restora_widgets.dart';
import '../../authentication/screens/login_screen.dart';
import '../../authentication/state/auth_controller.dart';
import '../data/session_repository.dart';
import '../data/session_summary.dart';
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

  String _dateTime(BuildContext context, DateTime timestamp) {
    final local = timestamp.toLocal();
    final labels = MaterialLocalizations.of(context);
    return '${labels.formatMediumDate(local)}, ${labels.formatYear(local)} · '
        '${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
  }

  String _stopReason(String reason) => switch (reason) {
    'user_stopped' => 'Stopped by you',
    'tracking_lost' => 'Stopped when tracking was lost',
    'app_inactive' => 'Stopped when the app left the foreground',
    _ => 'Session stopped',
  };

  Widget _sessionCard(BuildContext context, SavedSession session) =>
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  '${session.repetitions} complete repetitions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Chip(
                  avatar: Icon(
                    session.trackingMode == 'simulated'
                        ? Icons.science_outlined
                        : Icons.videocam_outlined,
                    size: 18,
                  ),
                  label: Text(session.trackingMode.toUpperCase()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Elbow flexion / extension'),
            const SizedBox(height: 8),
            Text(
              _dateTime(context, session.startedAt),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _stopReason(session.stopReason),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Session history'),
      actions: [
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => IconButton(
            tooltip: 'Refresh history',
            onPressed: _controller.loading ? null : _controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _controller.load,
        child: PageBody(
          children: [
            const SectionHeading(
              title: 'Your saved sessions',
              subtitle:
                  'Results saved to your account. Dates and times are shown in your local time.',
            ),
            const SizedBox(height: 24),
            if (_controller.loading)
              const SectionCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        semanticsLabel: 'Loading session history',
                      ),
                      SizedBox(height: 20),
                      Text('Loading your sessions…'),
                    ],
                  ),
                ),
              )
            else if (_controller.error case final message?)
              Semantics(
                liveRegion: true,
                child: StatePanel(
                  icon: _controller.authenticationRequired
                      ? Icons.lock_outline
                      : Icons.cloud_off_outlined,
                  title: _controller.authenticationRequired
                      ? 'Sign in to see your history'
                      : 'History could not be loaded',
                  message: message,
                  action: _controller.authenticationRequired
                      ? FilledButton.icon(
                          onPressed: () async {
                            final signedIn = await reauthenticate(
                              context,
                              widget.auth,
                            );
                            if (signedIn && mounted) {
                              await _controller.load();
                            }
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in again'),
                        )
                      : FilledButton.icon(
                          onPressed: _controller.load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry history'),
                        ),
                ),
              )
            else if (_controller.sessions.isEmpty)
              const StatePanel(
                icon: Icons.history_rounded,
                title: 'Your first session starts here',
                message:
                    'No sessions yet. Stop and save a demo session to see your results here.',
              )
            else ...[
              const StatusNotice(
                title: 'Demonstration results',
                message:
                    'SIMULATED sessions use test input. They do not represent camera tracking.',
                icon: Icons.science_outlined,
              ),
              const SizedBox(height: 20),
              for (final session in _controller.sessions) ...[
                _sessionCard(context, session),
                const SizedBox(height: 16),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}
