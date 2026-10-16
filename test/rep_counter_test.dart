import 'package:flutter_test/flutter_test.dart';
import 'package:restora_frontend/features/exercise/platform/pose_source.dart';
import 'package:restora_frontend/features/exercise/state/rep_counter.dart';

void main() {
  late RepCounter counter;
  void sample(int milliseconds, double? angle, {double confidence = 1}) =>
      counter.add(
        PoseSample(
          elapsed: Duration(milliseconds: milliseconds),
          elbowAngle: angle,
          confidence: confidence,
        ),
      );
  void hold(int start, double angle) {
    sample(start, angle);
    sample(start + 120, angle);
    sample(start + 240, angle);
  }

  setUp(() => counter = RepCounter());

  test('counts only full extended, flexed, extended cycles', () {
    hold(0, 60); // Beginning in flexion is not a cycle.
    hold(300, 160);
    expect(counter.repetitions, 0);
    hold(600, 60);
    expect(counter.repetitions, 0);
    hold(900, 160);
    expect(counter.repetitions, 1);
    hold(1200, 160); // Staying extended cannot count twice.
    expect(counter.repetitions, 1);
    hold(1500, 60);
    hold(1800, 160);
    expect(counter.repetitions, 2);
  });

  test('dwell rejects excursions and hysteresis tolerates small jitter', () {
    sample(0, 151);
    sample(100, 144);
    sample(200, 151);
    sample(300, 144);
    expect(counter.phase, RepPhase.awaitingExtension);
    sample(400, 150);
    sample(520, 148);
    sample(640, 151);
    expect(counter.phase, RepPhase.awaitingFlexion);
    sample(700, 69);
    sample(800, 76);
    sample(900, 69);
    sample(1000, 76);
    expect(counter.phase, RepPhase.awaitingFlexion);
    sample(1100, 70);
    sample(1220, 72);
    sample(1340, 69);
    sample(1400, 150);
    sample(1520, 149);
    sample(1640, 151);
    expect(counter.repetitions, 1);
  });

  test(
    'missing landmarks discard a partial cycle and preserve completed ones',
    () {
      hold(0, 160);
      hold(300, 60);
      hold(600, 160);
      hold(900, 60);
      sample(1200, null);
      hold(1300, 160);
      expect(counter.repetitions, 1);
      hold(1600, 60);
      hold(1900, 160);
      expect(counter.repetitions, 2);
    },
  );

  test('sample gaps cannot finish partial repetitions', () {
    hold(0, 160);
    hold(300, 60);
    hold(1500, 160);
    expect(counter.repetitions, 0);
    expect(counter.phase, RepPhase.awaitingFlexion);
    hold(1800, 60);
    hold(2100, 160);
    expect(counter.repetitions, 1);
  });

  test(
    'low confidence, invalid angles and stale timestamps reset partials',
    () {
      for (final invalid in [
        const PoseSample(
          elapsed: Duration(milliseconds: 600),
          elbowAngle: 160,
          confidence: 0.5,
        ),
        const PoseSample(
          elapsed: Duration(milliseconds: 600),
          elbowAngle: double.nan,
          confidence: 1,
        ),
        const PoseSample(
          elapsed: Duration(milliseconds: 600),
          elbowAngle: 181,
          confidence: 1,
        ),
        const PoseSample(
          elapsed: Duration(milliseconds: 400),
          elbowAngle: 160,
          confidence: 1,
        ),
      ]) {
        counter.reset();
        hold(0, 160);
        hold(300, 60);
        counter.add(invalid);
        hold(900, 160);
        expect(counter.repetitions, 0);
      }
    },
  );

  test('explicit watchdog interruption resets the partial cycle', () {
    hold(0, 160);
    hold(300, 60);
    counter.interrupt();
    hold(600, 160);
    expect(counter.repetitions, 0);
    expect(counter.tracking, true);
  });
}
