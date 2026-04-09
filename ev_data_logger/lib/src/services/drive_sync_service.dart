import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/app_secrets.dart';
import '../models/sync_queue_item.dart';
import 'trip_persistence_service.dart';

class SyncStatus {
  const SyncStatus({
    required this.pendingCount,
    required this.isFlushing,
    required this.lastSuccessUtc,
    required this.lastError,
  });

  final int pendingCount;
  final bool isFlushing;
  final DateTime? lastSuccessUtc;
  final String? lastError;
}

class DriveSyncService {
  DriveSyncService(this._persistence, {http.Client? client})
    : _client = client ?? http.Client();

  final TripPersistenceService _persistence;
  final http.Client _client;

  final List<SyncQueueItem> _queue = <SyncQueueItem>[];
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  bool _initialized = false;
  bool _isFlushing = false;
  DateTime? _lastSuccessUtc;
  String? _lastError;

  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus get status => SyncStatus(
    pendingCount: _queue.length,
    isFlushing: _isFlushing,
    lastSuccessUtc: _lastSuccessUtc,
    lastError: _lastError,
  );

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final List<SyncQueueItem> saved = await _persistence.loadSyncQueue();
    _queue
      ..clear()
      ..addAll(saved);
    _initialized = true;
    _emitStatus();
    unawaited(flush());
  }

  Future<void> enqueueMovement(Map<String, dynamic> payload) async {
    await _enqueue('movement', payload);
  }

  Future<void> enqueueCharging(Map<String, dynamic> payload) async {
    await _enqueue('charging', payload);
  }

  Future<void> _enqueue(String target, Map<String, dynamic> payload) async {
    if (!_initialized) {
      await initialize();
    }

    _queue.add(
      SyncQueueItem(
        id: const Uuid().v4(),
        target: target,
        payload: payload,
        createdAtUtc: DateTime.now().toUtc(),
        retryCount: 0,
        nextAttemptUtc: DateTime.now().toUtc(),
      ),
    );
    await _persistQueue();
    _emitStatus();
    unawaited(flush());
  }

  Future<void> flush() async {
    if (_isFlushing) {
      return;
    }
    if (!_initialized) {
      await initialize();
    }

    _isFlushing = true;
    _emitStatus();
    try {
      int index = 0;
      while (index < _queue.length) {
        final SyncQueueItem item = _queue[index];
        final DateTime now = DateTime.now().toUtc();
        if (item.nextAttemptUtc.isAfter(now)) {
          index += 1;
          continue;
        }

        final bool ok = await _send(item);
        if (ok) {
          _queue.removeAt(index);
          _lastSuccessUtc = DateTime.now().toUtc();
          _lastError = null;
          await _persistQueue();
          _emitStatus();
          continue;
        }

        final int nextRetry = item.retryCount + 1;
        final int waitSeconds = min(300, 1 << min(8, nextRetry));
        _queue[index] = item.copyWith(
          retryCount: nextRetry,
          nextAttemptUtc: DateTime.now().toUtc().add(
            Duration(seconds: waitSeconds),
          ),
        );
        await _persistQueue();
        _emitStatus();
        index += 1;
      }
    } finally {
      _isFlushing = false;
      _emitStatus();
    }
  }

  Future<bool> _send(SyncQueueItem item) async {
    final String endpoint = item.target == 'charging'
        ? chargingWebhookUrl
        : movementWebhookUrl;
    if (endpoint.isEmpty) {
      _lastError = 'Webhook URL for ${item.target} is empty';
      return false;
    }

    try {
      final http.Response response = await _client
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              if (driveWebhookApiKey.isNotEmpty)
                'X-API-KEY': driveWebhookApiKey,
            },
            body: jsonEncode(item.payload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }

      _lastError =
          'HTTP ${response.statusCode} on ${item.target}: ${response.body}';
      return false;
    } catch (error) {
      _lastError = '$error';
      return false;
    }
  }

  Future<void> _persistQueue() async {
    await _persistence.saveSyncQueue(_queue);
  }

  void _emitStatus() {
    if (_statusController.isClosed) {
      return;
    }
    _statusController.add(status);
  }

  void dispose() {
    _statusController.close();
  }
}
