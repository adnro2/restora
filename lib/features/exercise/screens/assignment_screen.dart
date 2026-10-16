import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/ui/restora_theme.dart';
import '../../../core/ui/restora_widgets.dart';
import '../../authentication/screens/login_screen.dart';
import '../../authentication/state/auth_controller.dart';
import '../../sessions/data/session_repository.dart';
import '../../sessions/screens/history_screen.dart';
import '../data/assignment.dart';
import '../data/assignment_repository.dart';
import '../platform/simulated_pose_source.dart';
import '../state/assignment_controller.dart';
import '../state/exercise_controller.dart';
import 'exercise_screen.dart';

class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({required this.api, required this.auth, super.key});
  final ApiClient api;
  final AuthController auth;

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  late final _controller = AssignmentController(
    AssignmentRepository(widget.api),
  );
  late final _sessions = ApiSessionRepository(widget.api);
  bool _signingOut = false;
  String? _signOutError;

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

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
      _signOutError = null;
    });
    await widget.auth.logout();
    if (!mounted) return;
    setState(() {
      _signingOut = false;
      if (widget.auth.token != null) {
        _signOutError =
            'We could not sign you out on this device. Please try again.';
      }
    });
  }

  Future<void> _signInAgain() async {
    if (_signingOut) return;
    if (await reauthenticate(context, widget.auth) && mounted) {
      await _controller.load();
    }
  }

  void _openSession(Assignment assignment) {
    if (_signingOut) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ExerciseScreen(
          auth: widget.auth,
          controller: ExerciseController(
            assignment: assignment,
            source: SimulatedPoseSource(),
            sessions: _sessions,
          ),
        ),
      ),
    );
  }

  void _openHistory() {
    if (_signingOut) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(repository: _sessions, auth: widget.auth),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Restora'),
      actions: [
        IconButton(
          tooltip: 'Session history',
          icon: const Icon(Icons.history_rounded),
          onPressed: _signingOut ? null : _openHistory,
        ),
        IconButton(
          tooltip: 'Sign out',
          icon: _signingOut
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          onPressed: _signingOut ? null : _signOut,
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _controller.load,
        child: PageBody(
          children: [
            const SectionHeading(
              title: 'Your exercise',
              subtitle: 'Review the movement, then take it one step at a time.',
            ),
            if (_signOutError case final message?) ...[
              StatusNotice(
                title: 'Could not sign out',
                message: message,
                tone: NoticeTone.error,
              ),
              const SizedBox(height: 16),
            ],
            if (_controller.loading)
              const StatePanel(
                icon: Icons.accessibility_new_rounded,
                title: 'Loading your exercise',
                message: 'Retrieving your assignment.',
                loading: true,
              )
            else if (_controller.error case final message?)
              StatePanel(
                icon: _controller.authenticationRequired
                    ? Icons.lock_outline_rounded
                    : Icons.cloud_off_rounded,
                title: _controller.authenticationRequired
                    ? 'Sign in to continue'
                    : 'Your exercise could not load',
                message: message,
                action: FilledButton.icon(
                  onPressed: _signingOut
                      ? null
                      : _controller.authenticationRequired
                      ? _signInAgain
                      : _controller.load,
                  icon: Icon(
                    _controller.authenticationRequired
                        ? Icons.login_rounded
                        : Icons.refresh_rounded,
                  ),
                  label: Text(
                    _controller.authenticationRequired
                        ? 'Sign in again'
                        : 'Retry assignment',
                  ),
                ),
              )
            else if (_controller.assignment case final assignment?) ...[
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ASSIGNED EXERCISE',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                              color: RestoraColors.muted,
                            ),
                          ),
                        ),
                        ElbowMotionGraphic(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      assignment.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: RestoraColors.paleTeal,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.repeat_rounded,
                            size: 20,
                            color: RestoraColors.teal,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Demo target: ${assignment.targetRepetitions} complete repetitions',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _signingOut
                          ? null
                          : () => _openSession(assignment),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Open simulated session'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'SIMULATED INPUT · This demo does not use your camera.',
                      style: TextStyle(
                        color: RestoraColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const StatusNotice(
                title: 'Demonstration defaults',
                message:
                    'Thresholds, repetition targets, and instructions require professional review before patient use.',
                tone: NoticeTone.warning,
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 28),
              const SectionHeading(
                title: 'Before you begin',
                subtitle:
                    'These instructions are for the engineering demonstration.',
              ),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (
                      var i = 0;
                      i < assignment.instructions.length;
                      i++
                    ) ...[
                      if (i > 0) const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: RestoraColors.paleTeal,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: RestoraColors.teal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(assignment.instructions[i])),
                        ],
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(height: 1),
                    ),
                    Text(
                      'Demo angle defaults: flexed ≤ ${assignment.flexedThreshold.toStringAsFixed(0)}° · extended ≥ ${assignment.extendedThreshold.toStringAsFixed(0)}°',
                      style: const TextStyle(
                        fontSize: 13,
                        color: RestoraColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _signingOut ? null : _openHistory,
                icon: const Icon(Icons.history_rounded),
                label: const Text('View session history'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
