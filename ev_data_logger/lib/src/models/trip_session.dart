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
      tripId: json['tripId'] as String,
      vehicleType: (json['vehicleType'] as String?) ?? 'Electric Vehicle',
      startSoc: json['startSoc'] as int,
      payloadKg: (json['payloadKg'] as num).toDouble(),
      startTimeUtc: DateTime.parse(json['startTimeUtc'] as String).toUtc(),
      tempCsvPath: json['tempCsvPath'] as String,
      weatherCondition: json['weatherCondition'] as String,
      ambientTempC: (json['ambientTempC'] as num?)?.toDouble(),
    );
  }
}
