class TelemetryLiveSnapshot {
  const TelemetryLiveSnapshot({
    required this.timestampUtc,
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
    required this.vehicleType,
    required this.sampleCount,
    required this.elapsedSec,
    required this.distanceKm,
  });

  final DateTime timestampUtc;
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
  final String vehicleType;
  final int sampleCount;
  final int elapsedSec;
  final double distanceKm;

  factory TelemetryLiveSnapshot.fromMap(Map<String, dynamic> map) {
    return TelemetryLiveSnapshot(
      timestampUtc: DateTime.parse(map['timestamp'] as String).toUtc(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      speedKmh: (map['speed_kmh'] as num).toDouble(),
      altitudeM: (map['altitude_m'] as num).toDouble(),
      accelerationMs2: (map['acceleration_ms2'] as num).toDouble(),
      startSoc: map['start_soc'] as int,
      endSoc: map['end_soc'] as int?,
      payloadKg: (map['payload_kg'] as num).toDouble(),
      ambientTempC: (map['ambient_temp_c'] as num?)?.toDouble(),
      weatherCondition: map['weather_condition'] as String,
      vehicleType: (map['vehicle_type'] as String?) ?? 'Electric Vehicle',
      sampleCount: map['sample_count'] as int,
      elapsedSec: map['elapsed_sec'] as int,
      distanceKm: (map['distance_km'] as num).toDouble(),
    );
  }
}
