class WeatherSnapshot {
  const WeatherSnapshot({required this.condition, required this.ambientTempC});

  final String condition;
  final double? ambientTempC;

  WeatherSnapshot fallbackUnknown() {
    return const WeatherSnapshot(condition: 'unknown', ambientTempC: null);
  }
}
