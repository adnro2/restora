import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/restora_theme.dart';
import '../../../core/ui/restora_widgets.dart';
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
        title: const Text('Discard unsaved session?'),
        content: const Text('Leaving will discard these unsaved results.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep results'),
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

  String get _instruction => switch (_controller.counter.phase) {
    RepPhase.awaitingExtension => 'Extend to establish the start position.',
    RepPhase.awaitingFlexion => 'Flex the elbow, then hold briefly.',
    RepPhase.awaitingReturn => 'Return to extension to complete one cycle.',
  };

  Widget _actions() {
    if (_controller.saving || _controller.starting) {
      return FilledButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(_controller.saving ? 'Saving results…' : 'Starting…'),
      );
    }
    if (_controller.running) {
      return FilledButton.icon(
        onPressed: _controller.stop,
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('Stop and save'),
      );
    }
    if (_controller.pending != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _controller.retrySave,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry save'),
          ),
          TextButton(
            onPressed: _discard,
            child: const Text('Discard unsaved session'),
          ),
        ],
      );
    }
    if (_controller.saved != null) {
      return FilledButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.check_rounded),
        label: const Text('Done'),
      );
    }
    return FilledButton.icon(
      onPressed: _controller.start,
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('Start simulated session'),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final source = _controller.source;
      final count = _controller.counter.repetitions;
      final target = _controller.assignment.targetRepetitions;
      final progress = target > 0 ? (count / target).clamp(0.0, 1.0) : 0.0;
      final canLeave =
          _discarded ||
          (!_controller.running &&
              !_controller.starting &&
              _controller.pending == null &&
              !_controller.saving);
      final interrupted = _controller.running && !_controller.counter.tracking;
      final statusMessage = _controller.running
          ? (_controller.counter.tracking
                ? _instruction
                : 'Simulated landmarks are unavailable. A partial cycle will not count.')
          : _controller.saving
          ? 'Keep this screen open while your stopped session is saved.'
          : _controller.saved != null
          ? 'Your results are saved in session history.'
          : _controller.pending != null
          ? 'Your results stay available while this screen is open.'
          : _controller.starting
          ? 'Preparing simulated movement input.'
          : 'Start when you are ready. Results are saved after you stop.';
      return PopScope(
        canPop: canLeave,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Stop before leaving. Save your results or explicitly discard an unsaved session.',
                ),
              ),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Demo session')),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: SizedBox(width: double.infinity, child: _actions()),
                ),
              ),
            ),
          ),
          body: PageBody(
            children: [
              const StatusNotice(
                title: 'SIMULATED INPUT · NO CAMERA TRACKING',
                message:
                    'Demonstration defaults require professional review before patient use.',
                tone: NoticeTone.warning,
                icon: Icons.science_outlined,
              ),
              const SizedBox(height: 24),
              const SectionHeading(
                title: 'One complete movement at a time',
                subtitle: 'Elbow flexion / extension demonstration',
              ),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SESSION PROGRESS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: RestoraColors.muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                liveRegion: true,
                                label: '$count complete repetitions',
                                excludeSemantics: true,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      fontSize: 76,
                                      fontWeight: FontWeight.w700,
                                      height: 1.05,
                                      color: RestoraColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'complete repetitions',
                                style: TextStyle(color: RestoraColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 92,
                          height: 92,
                          child: ElbowMotionGraphic(
                            angle:
                                _controller.angle ??
                                (source is SimulatedPoseSource
                                    ? source.angle
                                    : 110),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: RestoraColors.paleTeal,
                        semanticsLabel:
                            'Demo target progress: $count of $target repetitions',
                        semanticsValue: '${(progress * 100).round()}',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Demo target: $target complete repetitions',
                      style: const TextStyle(
                        fontSize: 13,
                        color: RestoraColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: StatusNotice(
                  title: _controller.trackingStatus,
                  message: statusMessage,
                  tone: interrupted || _controller.pending != null
                      ? NoticeTone.warning
                      : NoticeTone.info,
                  icon: _controller.saved != null
                      ? Icons.check_circle_outline_rounded
                      : interrupted
                      ? Icons.visibility_off_outlined
                      : Icons.radio_button_checked_rounded,
                ),
              ),
              if (_controller.error case final message?) ...[
                const SizedBox(height: 16),
                StatusNotice(
                  title: _controller.pending == null
                      ? 'Session could not start'
                      : 'Your results have not saved',
                  message: message,
                  tone: NoticeTone.error,
                  icon: Icons.error_outline_rounded,
                ),
                if (_controller.pending != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Your results are retained while this screen stays open. Check your connection, then retry save.',
                      style: TextStyle(color: RestoraColors.muted),
                    ),
                  ),
                if (_controller.authenticationRequired)
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (await reauthenticate(context, widget.auth) &&
                          mounted) {
                        await _controller.retrySave();
                      }
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Sign in again and retry save'),
                  ),
              ],
              if (source is SimulatedPoseSource &&
                  _controller.saved == null &&
                  _controller.pending == null) ...[
                const SizedBox(height: 28),
                const SectionHeading(
                  title: 'Try the movement',
                  subtitle: 'Use the slider to simulate a full cycle.',
                ),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Simulated elbow angle',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${source.angle.round()}°',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: source.angle,
                        min: 30,
                        max: 175,
                        divisions: 145,
                        label: '${source.angle.round()}°',
                        semanticFormatterCallback: (value) =>
                            '${value.round()} degrees, simulated elbow angle',
                        onChanged: _controller.running
                            ? (value) => setState(() => source.angle = value)
                            : null,
                      ),
                      Text(
                        'Extend ≥${_controller.assignment.extendedThreshold.round()}°, flex ≤${_controller.assignment.flexedThreshold.round()}°, then extend. Hold about 0.3 seconds at each end.',
                        style: const TextStyle(color: RestoraColors.muted),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Simulated landmarks visible'),
                        subtitle: const Text(
                          'Turn off to try an interruption. Partial cycles reset.',
                        ),
                        value: source.landmarksVisible,
                        onChanged: _controller.running
                            ? (value) => setState(
                                () => source.landmarksVisible = value,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
