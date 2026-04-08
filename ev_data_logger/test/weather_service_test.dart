import 'package:ev_data_logger/src/models/weather_snapshot.dart';
import 'package:ev_data_logger/src/services/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weather fallback can be represented as unknown', () {
    final WeatherSnapshot fallback = const WeatherSnapshot(
      condition: 'unknown',
      ambientTempC: null,
    );
    expect(fallback.condition, 'unknown');
    expect(fallback.ambientTempC, isNull);
  });

  test('parseSnapshot returns null for invalid payload', () {
    final WeatherService service = WeatherService();
    expect(service.parseSnapshot('{"invalid":true}'), isNull);
  });
}
