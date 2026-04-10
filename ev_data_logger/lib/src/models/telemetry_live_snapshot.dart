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
    required this.effectivePayloadKg,
    required this.passengerOn,
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
  final double effectivePayloadKg;
  final bool passengerOn;
  final double? ambientTempC;
  final String weatherCondition;
  final String vehicleType;
  final int sampleCount;
  final int elapsedSec;
  final double distanceKm;

  factory TelemetryLiveSnapshot.fromMap(Map<String, dynamic> map) {
    final DateTime timestampUtc = _parseTimestamp(
      map['timestamp'] ?? map['timestamp_utc'],
    );
    return TelemetryLiveSnapshot(
      timestampUtc: timestampUtc,
      latitude: _asDouble(map['latitude']) ?? 0,
      longitude: _asDouble(map['longitude']) ?? 0,
      speedKmh: _asDouble(map['speed_kmh']) ?? 0,
      altitudeM: _asDouble(map['altitude_m']) ?? 0,
      accelerationMs2: _asDouble(map['acceleration_ms2']) ?? 0,
      startSoc: _asInt(map['start_soc']) ?? 0,
      endSoc: _asInt(map['end_soc']),
      payloadKg: _asDouble(map['payload_kg']) ?? 0,
      effectivePayloadKg:
          _asDouble(map['effective_payload_kg']) ??
          (_asDouble(map['payload_kg']) ?? 0),
      passengerOn: _asBool(map['passenger_on']) ?? false,
      ambientTempC: _asDouble(map['ambient_temp_c']),
      weatherCondition: (map['weather_condition'] as String?) ?? 'unknown',
      vehicleType: (map['vehicle_type'] as String?) ?? 'Electric Vehicle',
      sampleCount: _asInt(map['sample_count']) ?? 0,
      elapsedSec: _asInt(map['elapsed_sec']) ?? 0,
      distanceKm: _asDouble(map['distance_km']) ?? 0,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }

  static int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
    }
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return double.tryParse(trimmed);
    }
    return null;
  }

  static bool? _asBool(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no' ||
          normalized.isEmpty) {
        return false;
      }
    }
    return null;
  }
}
