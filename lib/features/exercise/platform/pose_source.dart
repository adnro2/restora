/// A capture-time timestamp from a session-local monotonic clock. A future
/// camera adapter must emit missing landmarks immediately, preserve capture
/// timestamps, discard stale inference, and keep all frames on this device.
class PoseSample {
  const PoseSample({
    required this.elapsed,
    this.elbowAngle,
    this.confidence = 0,
  });
  final Duration elapsed;
  final double? elbowAngle;
  final double confidence;

  bool get usable =>
      elbowAngle != null &&
      elbowAngle!.isFinite &&
      elbowAngle! >= 0 &&
      elbowAngle! <= 180 &&
      confidence >= 0.7;
}

abstract interface class PoseSource {
  String get trackingMode;
  Stream<PoseSample> get samples;
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
