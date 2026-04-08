import 'package:ev_data_logger/src/utils/trip_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accelerationMs2', () {
    test('returns positive when speed increases', () {
      final double value = accelerationMs2(
        previousSpeedMps: 5,
        currentSpeedMps: 8,
        deltaSec: 1,
      );
      expect(value, 3);
    });

    test('returns negative when speed decreases', () {
      final double value = accelerationMs2(
        previousSpeedMps: 8,
        currentSpeedMps: 5,
        deltaSec: 1,
      );
      expect(value, -3);
    });

    test('returns zero when speed unchanged', () {
      final double value = accelerationMs2(
        previousSpeedMps: 8,
        currentSpeedMps: 8,
        deltaSec: 1,
      );
      expect(value, 0);
    });
  });
}
