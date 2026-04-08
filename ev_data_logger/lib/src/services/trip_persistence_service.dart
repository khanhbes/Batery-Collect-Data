import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

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
}
