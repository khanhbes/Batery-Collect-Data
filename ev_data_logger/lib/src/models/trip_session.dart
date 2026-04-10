import '../utils/type_helpers.dart';

class TripSession {
  const TripSession({
    required this.tripId,
    required this.vehicleType,
    required this.startSoc,
    required this.payloadKg,
    required this.startTimeUtc,
    required this.tempCsvPath,
    required this.weatherCondition,
    required this.ambientTempC,
  });

  final String tripId;
  final String vehicleType;
  final int startSoc;
  final double payloadKg;
  final DateTime startTimeUtc;
  final String tempCsvPath;
  final String weatherCondition;
  final double? ambientTempC;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tripId': tripId,
      'vehicleType': vehicleType,
      'startSoc': startSoc,
      'payloadKg': payloadKg,
      'startTimeUtc': startTimeUtc.toIso8601String(),
      'tempCsvPath': tempCsvPath,
      'weatherCondition': weatherCondition,
      'ambientTempC': ambientTempC,
    };
  }

  factory TripSession.fromJson(Map<String, dynamic> json) {
    return TripSession(
      tripId: toStringLoose(json['tripId']),
      vehicleType: toStringLoose(json['vehicleType'], fallback: 'Electric Vehicle'),
      startSoc: toIntLoose(json['startSoc']) ?? 0,
      payloadKg: toDoubleLoose(json['payloadKg']) ?? 0,
      startTimeUtc: DateTime.parse(toStringLoose(json['startTimeUtc'])).toUtc(),
      tempCsvPath: toStringLoose(json['tempCsvPath']),
      weatherCondition: toStringLoose(json['weatherCondition'], fallback: 'unknown'),
      ambientTempC: toDoubleLoose(json['ambientTempC']),
    );
  }
}
