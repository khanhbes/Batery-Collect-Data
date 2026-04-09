class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.target,
    required this.payload,
    required this.createdAtUtc,
    required this.retryCount,
    required this.nextAttemptUtc,
  });

  final String id;
  final String target; // movement | charging
  final Map<String, dynamic> payload;
  final DateTime createdAtUtc;
  final int retryCount;
  final DateTime nextAttemptUtc;

  SyncQueueItem copyWith({
    String? id,
    String? target,
    Map<String, dynamic>? payload,
    DateTime? createdAtUtc,
    int? retryCount,
    DateTime? nextAttemptUtc,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      target: target ?? this.target,
      payload: payload ?? this.payload,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      retryCount: retryCount ?? this.retryCount,
      nextAttemptUtc: nextAttemptUtc ?? this.nextAttemptUtc,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'target': target,
      'payload': payload,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'retryCount': retryCount,
      'nextAttemptUtc': nextAttemptUtc.toIso8601String(),
    };
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      target: json['target'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
      retryCount: (json['retryCount'] as num).toInt(),
      nextAttemptUtc: DateTime.parse(json['nextAttemptUtc'] as String).toUtc(),
    );
  }
}
