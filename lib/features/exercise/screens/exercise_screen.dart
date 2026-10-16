import 'dart:async';

import 'package:flutter/material.dart';

import '../../authentication/screens/login_screen.dart';
import '../../authentication/state/auth_controller.dart';
import '../platform/simulated_pose_source.dart';
import '../state/exercise_controller.dart';
import '../state/rep_counter.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({
    required this.controller,
    required this.auth,
    super.key,
  });
  final ExerciseController controller;
  final AuthController auth;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with WidgetsBindingObserver {
  bool _discarded = false;
  ExerciseController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_controller.appInactive());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved summary?'),
        content: const Text(
          'This summary exists only in memory. Leaving now permanently discards it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep summary'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _discarded = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final source = _controller.source;
      final canLeave =
          _discarded ||
          (!_controller.running &&
              !_controller.starting &&
              _controller.pending == null &&
              !_controller.saving);
      final instruction = switch (_controller.counter.phase) {
        RepPhase.awaitingExtension => 'Extend to establish the start position.',
        RepPhase.awaitingFlexion => 'Flex the elbow, then hold briefly.',
        RepPhase.awaitingReturn => 'Return to extension to complete one cycle.',
      };
      return PopScope(
        canPop: canLeave,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Stop and save before leaving, or explicitly discard an unsaved summary.',
                ),
              ),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Elbow movement demo')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Card(
                color: Color(0xffffe8bd),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'SIMULATED INPUT — NO CAMERA TRACKING\nIntegration testing only. Demonstration defaults require professional review before patient use.',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  '${_controller.counter.repetitions}',
                  style: Theme.of(context).textTheme.displayLarge,
                  semanticsLabel:
                      '${_controller.counter.repetitions} complete repetitions',
                ),
              ),
              Center(
                child: Text(
                  'Completed repetitions · demo target ${_controller.assignment.targetRepetitions}',
                ),
              ),
              const SizedBox(height: 16),
              Text(_controller.trackingStatus, textAlign: TextAlign.center),
              if (_controller.running) ...[
                Text(instruction, textAlign: TextAlign.center),
                Text(
                  'Angle: ${_controller.angle?.toStringAsFixed(0) ?? 'unavailable'}°',
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              if (source is SimulatedPoseSource) ...[
                Text('Simulated elbow angle: ${source.angle.round()}°'),
                Slider(
                  value: source.angle,
                  min: 30,
                  max: 175,
                  divisions: 145,
                  label: '${source.angle.round()}°',
                  onChanged: _controller.running
                      ? (value) => setState(() => source.angle = value)
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Simulated landmarks visible'),
                  subtitle: const Text(
                    'Turn off to test interruption and partial-cycle reset.',
                  ),
                  value: source.landmarksVisible,
                  onChanged: _controller.running
                      ? (value) =>
                            setState(() => source.landmarksVisible = value)
                      : null,
                ),
                const Text(
                  'Hold ≥150° → ≤70° → ≥150°, about 0.3 seconds at each end. These are engineering demonstration defaults.',
                ),
              ],
              const SizedBox(height: 20),
              if (!_controller.running &&
                  !_controller.starting &&
                  _controller.pending == null &&
                  _controller.saved == null)
                FilledButton(
                  onPressed: _controller.start,
                  child: const Text('Start simulated session'),
                ),
              if (_controller.starting)
                const Center(child: CircularProgressIndicator()),
              if (_controller.running)
                FilledButton(
                  onPressed: _controller.stop,
                  child: const Text('Stop and save'),
                ),
              if (_controller.saving)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Saving stopped summary…'),
                    ],
                  ),
                ),
              if (_controller.error case final message?) ...[
                Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                if (_controller.pending != null)
                  const Text(
                    'Your results are retained while this screen stays open. Check your connection, then retry save.',
                  ),
              ],
              if (_controller.authenticationRequired)
                TextButton(
                  onPressed: () async {
                    if (await reauthenticate(context, widget.auth)) {
                      await _controller.retrySave();
                    }
                  },
                  child: const Text('Sign in again and retry save'),
                ),
              if (_controller.pending != null && !_controller.saving) ...[
                FilledButton(
                  onPressed: _controller.retrySave,
                  child: const Text('Retry save'),
                ),
                TextButton(
                  onPressed: _discard,
                  child: const Text('Discard unsaved session'),
                ),
              ],
              if (_controller.saved != null) ...[
                const Text(
                  'Saved. View this session in History.',
                  textAlign: TextAlign.center,
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
