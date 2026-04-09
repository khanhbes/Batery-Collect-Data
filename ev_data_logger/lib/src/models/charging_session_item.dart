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
    };
  }

  factory ChargingSessionItem.fromJson(Map<String, dynamic> json) {
    return ChargingSessionItem(
      chargeId: json['chargeId'] as String,
      startTimestampUtc: DateTime.parse(
        json['startTimestampUtc'] as String,
      ).toUtc(),
      endTimestampUtc: json['endTimestampUtc'] == null
          ? null
          : DateTime.parse(json['endTimestampUtc'] as String).toUtc(),
      startSoc: json['startSoc'] as int,
      endSoc: (json['endSoc'] as num?)?.toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      ambientTempC: (json['ambientTempC'] as num?)?.toDouble(),
    );
  }
}
