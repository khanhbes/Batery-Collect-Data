class TripHistoryItem {
  const TripHistoryItem({
    required this.tripId,
    required this.csvPath,
    required this.startSoc,
    required this.endSoc,
    required this.payloadKg,
    required this.startTimeUtc,
    required this.endTimeUtc,
    required this.durationSec,
    required this.totalDistanceKm,
  });

  final String tripId;
  final String csvPath;
  final int startSoc;
  final int endSoc;
  final double payloadKg;
  final DateTime startTimeUtc;
  final DateTime endTimeUtc;
  final int durationSec;
  final double totalDistanceKm;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tripId': tripId,
      'csvPath': csvPath,
      'startSoc': startSoc,
      'endSoc': endSoc,
      'payloadKg': payloadKg,
      'startTimeUtc': startTimeUtc.toIso8601String(),
      'endTimeUtc': endTimeUtc.toIso8601String(),
      'durationSec': durationSec,
      'totalDistanceKm': totalDistanceKm,
    };
  }

  factory TripHistoryItem.fromJson(Map<String, dynamic> json) {
    return TripHistoryItem(
      tripId: json['tripId'] as String,
      csvPath: json['csvPath'] as String,
      startSoc: json['startSoc'] as int,
      endSoc: json['endSoc'] as int,
      payloadKg: (json['payloadKg'] as num).toDouble(),
      startTimeUtc: DateTime.parse(json['startTimeUtc'] as String).toUtc(),
      endTimeUtc: DateTime.parse(json['endTimeUtc'] as String).toUtc(),
      durationSec: json['durationSec'] as int,
      totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
    );
  }
}
