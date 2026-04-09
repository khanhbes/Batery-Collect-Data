import 'route_point.dart';

class TripHistoryItem {
  const TripHistoryItem({
    required this.tripId,
    required this.vehicleType,
    required this.startTimeUtc,
    required this.endTimeUtc,
    required this.durationSec,
    required this.startSoc,
    required this.endSoc,
    required this.socDelta,
    required this.payloadKg,
    required this.sampleCount,
    required this.totalDistanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.avgAccelerationMs2,
    required this.maxAccelerationMs2,
    required this.minAltitudeM,
    required this.maxAltitudeM,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    required this.ambientTempC,
    required this.weatherCondition,
    required this.routePreview,
  });

  static const List<String> masterHeader = <String>[
    'trip_id',
    'vehicle_type',
    'start_time_utc',
    'end_time_utc',
    'duration_sec',
    'start_soc',
    'end_soc',
    'soc_delta',
    'payload_kg',
    'sample_count',
    'total_distance_km',
    'avg_speed_kmh',
    'max_speed_kmh',
    'avg_acceleration_ms2',
    'max_acceleration_ms2',
    'min_altitude_m',
    'max_altitude_m',
    'start_latitude',
    'start_longitude',
    'end_latitude',
    'end_longitude',
    'ambient_temp_c',
    'weather_condition',
  ];

  final String tripId;
  final String vehicleType;
  final DateTime startTimeUtc;
  final DateTime endTimeUtc;
  final int durationSec;
  final int startSoc;
  final int endSoc;
  final int socDelta;
  final double payloadKg;
  final int sampleCount;
  final double totalDistanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double avgAccelerationMs2;
  final double maxAccelerationMs2;
  final double minAltitudeM;
  final double maxAltitudeM;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final double? ambientTempC;
  final String weatherCondition;
  final List<RoutePoint> routePreview;

  List<dynamic> toMasterCsvRow() {
    return <dynamic>[
      tripId,
      vehicleType,
      startTimeUtc.toIso8601String(),
      endTimeUtc.toIso8601String(),
      durationSec,
      startSoc,
      endSoc,
      socDelta,
      payloadKg,
      sampleCount,
      totalDistanceKm,
      avgSpeedKmh,
      maxSpeedKmh,
      avgAccelerationMs2,
      maxAccelerationMs2,
      minAltitudeM,
      maxAltitudeM,
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
      ambientTempC ?? '',
      weatherCondition,
    ];
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tripId': tripId,
      'vehicleType': vehicleType,
      'startTimeUtc': startTimeUtc.toIso8601String(),
      'endTimeUtc': endTimeUtc.toIso8601String(),
      'durationSec': durationSec,
      'startSoc': startSoc,
      'endSoc': endSoc,
      'socDelta': socDelta,
      'payloadKg': payloadKg,
      'sampleCount': sampleCount,
      'totalDistanceKm': totalDistanceKm,
      'avgSpeedKmh': avgSpeedKmh,
      'maxSpeedKmh': maxSpeedKmh,
      'avgAccelerationMs2': avgAccelerationMs2,
      'maxAccelerationMs2': maxAccelerationMs2,
      'minAltitudeM': minAltitudeM,
      'maxAltitudeM': maxAltitudeM,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'ambientTempC': ambientTempC,
      'weatherCondition': weatherCondition,
      'routePreview': routePreview.map((RoutePoint e) => e.toJson()).toList(),
    };
  }

  factory TripHistoryItem.fromJson(Map<String, dynamic> json) {
    final List<dynamic> routeRaw =
        (json['routePreview'] as List<dynamic>?) ?? <dynamic>[];
    return TripHistoryItem(
      tripId: json['tripId'] as String,
      vehicleType: (json['vehicleType'] as String?) ?? 'Electric Vehicle',
      startTimeUtc: DateTime.parse(json['startTimeUtc'] as String).toUtc(),
      endTimeUtc: DateTime.parse(json['endTimeUtc'] as String).toUtc(),
      durationSec: json['durationSec'] as int,
      startSoc: json['startSoc'] as int,
      endSoc: json['endSoc'] as int,
      socDelta:
          (json['socDelta'] as num?)?.toInt() ??
          ((json['startSoc'] as int) - (json['endSoc'] as int)),
      payloadKg: (json['payloadKg'] as num).toDouble(),
      sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
      totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
      avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble() ?? 0,
      maxSpeedKmh: (json['maxSpeedKmh'] as num?)?.toDouble() ?? 0,
      avgAccelerationMs2: (json['avgAccelerationMs2'] as num?)?.toDouble() ?? 0,
      maxAccelerationMs2: (json['maxAccelerationMs2'] as num?)?.toDouble() ?? 0,
      minAltitudeM: (json['minAltitudeM'] as num?)?.toDouble() ?? 0,
      maxAltitudeM: (json['maxAltitudeM'] as num?)?.toDouble() ?? 0,
      startLatitude: (json['startLatitude'] as num?)?.toDouble() ?? 0,
      startLongitude: (json['startLongitude'] as num?)?.toDouble() ?? 0,
      endLatitude: (json['endLatitude'] as num?)?.toDouble() ?? 0,
      endLongitude: (json['endLongitude'] as num?)?.toDouble() ?? 0,
      ambientTempC: (json['ambientTempC'] as num?)?.toDouble(),
      weatherCondition: (json['weatherCondition'] as String?) ?? 'unknown',
      routePreview: routeRaw
          .whereType<Map>()
          .map((Map e) => RoutePoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
