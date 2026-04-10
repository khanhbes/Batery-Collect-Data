import '../utils/type_helpers.dart';
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
    this.rawDataPath,
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
  final String? rawDataPath;

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
      'rawDataPath': rawDataPath,
    };
  }

  factory TripHistoryItem.fromJson(Map<String, dynamic> json) {
    final List<dynamic> routeRaw =
        (json['routePreview'] as List<dynamic>?) ?? <dynamic>[];
    final int startSoc = toIntLoose(json['startSoc']) ?? 0;
    final int endSoc = toIntLoose(json['endSoc']) ?? 0;
    return TripHistoryItem(
      tripId: toStringLoose(json['tripId']),
      vehicleType: toStringLoose(json['vehicleType'], fallback: 'Electric Vehicle'),
      startTimeUtc: DateTime.parse(toStringLoose(json['startTimeUtc'])).toUtc(),
      endTimeUtc: DateTime.parse(toStringLoose(json['endTimeUtc'])).toUtc(),
      durationSec: toIntLoose(json['durationSec']) ?? 0,
      startSoc: startSoc,
      endSoc: endSoc,
      socDelta: toIntLoose(json['socDelta']) ?? (startSoc - endSoc),
      payloadKg: toDoubleLoose(json['payloadKg']) ?? 0,
      sampleCount: toIntLoose(json['sampleCount']) ?? 0,
      totalDistanceKm: toDoubleLoose(json['totalDistanceKm']) ?? 0,
      avgSpeedKmh: toDoubleLoose(json['avgSpeedKmh']) ?? 0,
      maxSpeedKmh: toDoubleLoose(json['maxSpeedKmh']) ?? 0,
      avgAccelerationMs2: toDoubleLoose(json['avgAccelerationMs2']) ?? 0,
      maxAccelerationMs2: toDoubleLoose(json['maxAccelerationMs2']) ?? 0,
      minAltitudeM: toDoubleLoose(json['minAltitudeM']) ?? 0,
      maxAltitudeM: toDoubleLoose(json['maxAltitudeM']) ?? 0,
      startLatitude: toDoubleLoose(json['startLatitude']) ?? 0,
      startLongitude: toDoubleLoose(json['startLongitude']) ?? 0,
      endLatitude: toDoubleLoose(json['endLatitude']) ?? 0,
      endLongitude: toDoubleLoose(json['endLongitude']) ?? 0,
      ambientTempC: toDoubleLoose(json['ambientTempC']),
      weatherCondition: toStringLoose(json['weatherCondition'], fallback: 'unknown'),
      routePreview: routeRaw
          .whereType<Map>()
          .map((Map e) => RoutePoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      rawDataPath: json['rawDataPath'] as String?,
    );
  }
}
