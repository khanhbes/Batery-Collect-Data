import '../utils/type_helpers.dart';

class ChargingSessionItem {
  const ChargingSessionItem({
    required this.chargeId,
    required this.startTimestampUtc,
    required this.endTimestampUtc,
    required this.startSoc,
    required this.endSoc,
    required this.latitude,
    required this.longitude,
    required this.ambientTempC,
    this.rawDataPath,
  });

  static const List<String> csvHeader = <String>[
    'charge_id',
    'start_timestamp',
    'end_timestamp',
    'start_soc',
    'end_soc',
    'latitude',
    'longitude',
    'ambient_temp_c',
  ];

  final String chargeId;
  final DateTime startTimestampUtc;
  final DateTime? endTimestampUtc;
  final int startSoc;
  final int? endSoc;
  final double latitude;
  final double longitude;
  final double? ambientTempC;
  final String? rawDataPath;

  bool get isCompleted => endTimestampUtc != null && endSoc != null;

  ChargingSessionItem copyWith({
    String? chargeId,
    DateTime? startTimestampUtc,
    DateTime? endTimestampUtc,
    int? startSoc,
    int? endSoc,
    double? latitude,
    double? longitude,
    double? ambientTempC,
    String? rawDataPath,
    bool clearEndTimestamp = false,
    bool clearEndSoc = false,
    bool clearAmbientTemp = false,
  }) {
    return ChargingSessionItem(
      chargeId: chargeId ?? this.chargeId,
      startTimestampUtc: startTimestampUtc ?? this.startTimestampUtc,
      endTimestampUtc: clearEndTimestamp
          ? null
          : endTimestampUtc ?? this.endTimestampUtc,
      startSoc: startSoc ?? this.startSoc,
      endSoc: clearEndSoc ? null : endSoc ?? this.endSoc,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      ambientTempC: clearAmbientTemp ? null : ambientTempC ?? this.ambientTempC,
      rawDataPath: rawDataPath ?? this.rawDataPath,
    );
  }

  List<dynamic> toCsvRow() {
    return <dynamic>[
      chargeId,
      startTimestampUtc.toIso8601String(),
      endTimestampUtc?.toIso8601String() ?? '',
      startSoc,
      endSoc ?? '',
      latitude,
      longitude,
      ambientTempC ?? '',
    ];
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'chargeId': chargeId,
      'startTimestampUtc': startTimestampUtc.toIso8601String(),
      'endTimestampUtc': endTimestampUtc?.toIso8601String(),
      'startSoc': startSoc,
      'endSoc': endSoc,
      'latitude': latitude,
      'longitude': longitude,
      'ambientTempC': ambientTempC,
      'rawDataPath': rawDataPath,
    };
  }

  factory ChargingSessionItem.fromJson(Map<String, dynamic> json) {
    return ChargingSessionItem(
      chargeId: toStringLoose(json['chargeId']),
      startTimestampUtc: DateTime.parse(
        toStringLoose(json['startTimestampUtc']),
      ).toUtc(),
      endTimestampUtc: json['endTimestampUtc'] == null
          ? null
          : DateTime.parse(toStringLoose(json['endTimestampUtc'])).toUtc(),
      startSoc: toIntLoose(json['startSoc']) ?? 0,
      endSoc: toIntLoose(json['endSoc']),
      latitude: toDoubleLoose(json['latitude']) ?? 0,
      longitude: toDoubleLoose(json['longitude']) ?? 0,
      ambientTempC: toDoubleLoose(json['ambientTempC']),
      rawDataPath: json['rawDataPath'] as String?,
    );
  }
}
