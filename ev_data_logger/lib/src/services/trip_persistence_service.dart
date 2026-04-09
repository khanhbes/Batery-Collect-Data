import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/charging_session_item.dart';
import '../models/sync_queue_item.dart';
import '../models/trip_history_item.dart';
import '../models/trip_session.dart';

class TripPersistenceService {
  TripPersistenceService({Directory? baseDirectory})
    : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;

  Future<Directory> _rootDir() async {
    if (_baseDirectory != null) {
      return _baseDirectory;
    }
    return getApplicationDocumentsDirectory();
  }

  Future<File> _activeTripFile() async {
    final Directory root = await _rootDir();
    return File('${root.path}/active_trip.json');
  }

  Future<File> _historyIndexFile() async {
    final Directory root = await _rootDir();
    return File('${root.path}/trip_history.json');
  }

  Future<File> _activeChargingFile() async {
    final Directory root = await _rootDir();
    return File('${root.path}/active_charging.json');
  }

  Future<File> _chargingHistoryIndexFile() async {
    final Directory root = await _rootDir();
    return File('${root.path}/charging_history.json');
  }

  Future<File> _syncQueueFile() async {
    final Directory root = await _rootDir();
    return File('${root.path}/sync_queue.json');
  }

  Future<void> saveActiveTrip(TripSession session) async {
    final File file = await _activeTripFile();
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  Future<TripSession?> loadActiveTrip() async {
    final File file = await _activeTripFile();
    if (!file.existsSync()) {
      return null;
    }
    final String raw = await file.readAsString();
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return TripSession.fromJson(decoded);
  }

  Future<void> clearActiveTrip() async {
    final File file = await _activeTripFile();
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<List<TripHistoryItem>> loadHistory() async {
    final File file = await _historyIndexFile();
    if (!file.existsSync()) {
      return <TripHistoryItem>[];
    }

    final String raw = await file.readAsString();
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <TripHistoryItem>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(TripHistoryItem.fromJson)
        .toList()
      ..sort((a, b) => b.startTimeUtc.compareTo(a.startTimeUtc));
  }

  Future<void> appendHistory(TripHistoryItem item) async {
    final List<TripHistoryItem> existing = await loadHistory();
    final List<TripHistoryItem> updated = <TripHistoryItem>[item, ...existing];
    final File file = await _historyIndexFile();
    await file.writeAsString(
      jsonEncode(updated.map((TripHistoryItem e) => e.toJson()).toList()),
    );
  }

  Future<void> saveActiveCharging(ChargingSessionItem session) async {
    final File file = await _activeChargingFile();
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  Future<ChargingSessionItem?> loadActiveCharging() async {
    final File file = await _activeChargingFile();
    if (!file.existsSync()) {
      return null;
    }
    final String raw = await file.readAsString();
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return ChargingSessionItem.fromJson(decoded);
  }

  Future<void> clearActiveCharging() async {
    final File file = await _activeChargingFile();
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<List<ChargingSessionItem>> loadChargingHistory() async {
    final File file = await _chargingHistoryIndexFile();
    if (!file.existsSync()) {
      return <ChargingSessionItem>[];
    }

    final String raw = await file.readAsString();
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <ChargingSessionItem>[];
    }

    return decoded
        .whereType<Map>()
        .map(
          (Map e) => ChargingSessionItem.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList()
      ..sort((a, b) => b.startTimestampUtc.compareTo(a.startTimestampUtc));
  }

  Future<void> appendChargingHistory(ChargingSessionItem item) async {
    final List<ChargingSessionItem> existing = await loadChargingHistory();
    final List<ChargingSessionItem> updated = <ChargingSessionItem>[
      item,
      ...existing,
    ];
    final File file = await _chargingHistoryIndexFile();
    await file.writeAsString(
      jsonEncode(updated.map((ChargingSessionItem e) => e.toJson()).toList()),
    );
  }

  Future<void> saveSyncQueue(List<SyncQueueItem> items) async {
    final File file = await _syncQueueFile();
    await file.writeAsString(
      jsonEncode(items.map((SyncQueueItem e) => e.toJson()).toList()),
    );
  }

  Future<List<SyncQueueItem>> loadSyncQueue() async {
    final File file = await _syncQueueFile();
    if (!file.existsSync()) {
      return <SyncQueueItem>[];
    }
    final String raw = await file.readAsString();
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <SyncQueueItem>[];
    }

    return decoded
        .whereType<Map>()
        .map((Map e) => SyncQueueItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
