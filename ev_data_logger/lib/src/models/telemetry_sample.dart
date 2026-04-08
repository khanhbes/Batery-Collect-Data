class TelemetrySample {
  const TelemetrySample({
    required this.timestampUtc,
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.altitudeM,
    required this.accelerationMs2,
    required this.startSoc,
    required this.endSoc,
    required this.payloadKg,
    required this.ambientTempC,
    required this.weatherCondition,
  });

  final DateTime timestampUtc;
  final String tripId;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double altitudeM;
  final double accelerationMs2;
  final int startSoc;
  final int? endSoc;
  final double payloadKg;
  final double? ambientTempC;
  final String weatherCondition;
}
