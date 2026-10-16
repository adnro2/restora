import '../platform/pose_source.dart';

enum RepPhase { awaitingExtension, awaitingFlexion, awaitingReturn }

/// Engineering defaults only; movement thresholds and dwell require
/// professional review and actual-phone testing before any patient use.
class RepCounter {
  RepCounter({
    this.flexedThreshold = 70,
    this.extendedThreshold = 150,
    this.hysteresis = 5,
    this.dwell = const Duration(milliseconds: 200),
    this.maximumGap = const Duration(milliseconds: 500),
  });

  final double flexedThreshold, extendedThreshold, hysteresis;
  final Duration dwell, maximumGap;
  int repetitions = 0;
  RepPhase phase = RepPhase.awaitingExtension;
  Duration? _last;
  Duration? _candidateSince;
  bool tracking = false;

  void reset() {
    repetitions = 0;
    interrupt();
  }

  /// Invalidates partial cycles without changing already completed repetitions.
  void interrupt() {
    phase = RepPhase.awaitingExtension;
    _candidateSince = null;
    _last = null;
    tracking = false;
  }

  void add(PoseSample sample) {
    final previous = _last;
    if (!sample.usable ||
        sample.elapsed.isNegative ||
        (previous != null && sample.elapsed <= previous)) {
      interrupt();
      return;
    }
    if (previous != null && sample.elapsed - previous > maximumGap) interrupt();
    _last = sample.elapsed;
    tracking = true;
    final angle = sample.elbowAngle!;
    final seekingFlexion = phase == RepPhase.awaitingFlexion;
    final entersZone = seekingFlexion
        ? angle <= flexedThreshold
        : angle >= extendedThreshold;
    final staysInZone = seekingFlexion
        ? angle <= flexedThreshold + hysteresis
        : angle >= extendedThreshold - hysteresis;
    if (_candidateSince == null && entersZone) _candidateSince = sample.elapsed;
    if (!staysInZone) _candidateSince = null;
    final candidate = _candidateSince;
    if (candidate == null || sample.elapsed - candidate < dwell) return;
    _candidateSince = null;
    switch (phase) {
      case RepPhase.awaitingExtension:
        phase = RepPhase.awaitingFlexion;
      case RepPhase.awaitingFlexion:
        phase = RepPhase.awaitingReturn;
      case RepPhase.awaitingReturn:
        repetitions++;
        phase = RepPhase.awaitingFlexion;
    }
  }
}
