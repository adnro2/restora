import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../authentication/screens/login_screen.dart';
import '../../authentication/state/auth_controller.dart';
import '../../sessions/data/session_repository.dart';
import '../../sessions/screens/history_screen.dart';
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
    appBar: AppBar(
      title: const Text('Your assignment'),
      actions: [
        IconButton(
          tooltip: 'Session history',
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  HistoryScreen(repository: _sessions, auth: widget.auth),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: widget.auth.logout,
        ),
      ],
    ),
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
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'DEMONSTRATION DEFAULTS\nThresholds, repetition targets, and instructions require professional review before patient use.',
                  ),
                ),
              ),
              if (_controller.error case final message?) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _controller.load,
                  child: const Text('Retry assignment'),
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
              if (_controller.assignment case final assignment?) ...[
                const SizedBox(height: 24),
                Text(
                  assignment.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(assignment.description),
                const SizedBox(height: 16),
                for (final instruction in assignment.instructions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• $instruction'),
                  ),
                Text(
                  'Demo target: ${assignment.targetRepetitions} complete cycles.\n'
                  'Demo angle defaults: flexed ≤ ${assignment.flexedThreshold.toStringAsFixed(0)}°, '
                  'extended ≥ ${assignment.extendedThreshold.toStringAsFixed(0)}°.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Open SIMULATED integration demo'),
                  onPressed: () => Navigator.push<void>(
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
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This integration demo uses simulated input and does not use your camera.',
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
