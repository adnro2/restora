import 'dart:async';

import 'pose_source.dart';

/// Integration test input only. This does not access a camera or run ML Kit.
class SimulatedPoseSource implements PoseSource {
  final _samples = StreamController<PoseSample>.broadcast();
  final _clock = Stopwatch();
  Timer? _timer;
  double angle = 160;
  bool landmarksVisible = true;

  @override
  String get trackingMode => 'simulated';

  @override
  Stream<PoseSample> get samples => _samples.stream;

  @override
  Future<void> start() async {
    _clock
      ..reset()
      ..start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      _samples.add(
        PoseSample(
          elapsed: _clock.elapsed,
          elbowAngle: landmarksVisible ? angle : null,
          confidence: landmarksVisible ? 1 : 0,
        ),
      );
    });
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _samples.close();
  }
}
