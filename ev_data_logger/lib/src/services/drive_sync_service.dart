import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/app_secrets.dart';
import '../models/sync_queue_item.dart';
import 'trip_persistence_service.dart';

class SyncTargetStatus {
  const SyncTargetStatus({
    required this.pendingCount,
    required this.isFlushing,
    required this.isPaused,
    required this.lastSuccessUtc,
    required this.lastError,
  });

  static const SyncTargetStatus empty = SyncTargetStatus(
    pendingCount: 0,
    isFlushing: false,
    isPaused: false,
    lastSuccessUtc: null,
    lastError: null,
  );

  final int pendingCount;
  final bool isFlushing;
  final bool isPaused;
  final DateTime? lastSuccessUtc;
  final String? lastError;
}

class SyncStatus {
  const SyncStatus({
    required this.movement,
    required this.charging,
  });

  static const SyncStatus empty = SyncStatus(
    movement: SyncTargetStatus.empty,
    charging: SyncTargetStatus.empty,
  );

  final SyncTargetStatus movement;
  final SyncTargetStatus charging;

  int get totalPending => movement.pendingCount + charging.pendingCount;
}

class DriveSyncService {
  DriveSyncService(this._persistence, {http.Client? client})
    : _client = client ?? http.Client();

  final TripPersistenceService _persistence;
  final http.Client _client;

  final List<SyncQueueItem> _movementQueue = <SyncQueueItem>[];
  final List<SyncQueueItem> _chargingQueue = <SyncQueueItem>[];
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  bool _initialized = false;
  bool _movementFlushing = false;
  bool _chargingFlushing = false;
  bool _movementPaused = false;
  bool _chargingPaused = false;
  DateTime? _movementLastSuccessUtc;
  DateTime? _chargingLastSuccessUtc;
  String? _movementLastError;
  String? _chargingLastError;

  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus get status => SyncStatus(
    movement: SyncTargetStatus(
      pendingCount: _movementQueue.length,
      isFlushing: _movementFlushing,
      isPaused: _movementPaused,
      lastSuccessUtc: _movementLastSuccessUtc,
      lastError: _movementLastError,
    ),
    charging: SyncTargetStatus(
      pendingCount: _chargingQueue.length,
      isFlushing: _chargingFlushing,
      isPaused: _chargingPaused,
      lastSuccessUtc: _chargingLastSuccessUtc,
      lastError: _chargingLastError,
    ),
  );

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    
    _validateWebhookUrl(movementWebhookUrl, 'movement');
    _validateWebhookUrl(chargingWebhookUrl, 'charging');
    
    final List<SyncQueueItem> saved = await _persistence.loadSyncQueue();
    _movementQueue.clear();
    _chargingQueue.clear();
    for (final SyncQueueItem item in saved) {
      if (item.target == 'charging') {
        _chargingQueue.add(item);
      } else {
        _movementQueue.add(item);
      }
    }
    _initialized = true;
    _emitStatus();
    unawaited(_flushAll());
  }

  void _validateWebhookUrl(String url, String target) {
    final String trimmed = url.trim();
    if (trimmed.isEmpty) {
      if (target == 'movement') {
        _movementLastError = 'Webhook URL for movement is empty';
      } else {
        _chargingLastError = 'Webhook URL for charging is empty';
      }
      return;
    }

    // Strict check: must be Google Apps Script Web App /exec URL
    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null ||
        !parsed.host.endsWith('script.google.com') ||
        !parsed.path.contains('/macros/') ||
        !parsed.path.endsWith('/exec')) {
      final String msg =
          'Invalid $target webhook URL. Must be Google Apps Script Web App '
          '(https://script.google.com/macros/s/.../exec)';
      if (target == 'movement') {
        _movementLastError = msg;
      } else {
        _chargingLastError = msg;
      }
      throw Exception(msg);
    }
  }

  /// Preflight check: GET the webhook URL and verify a valid JSON health
  /// response is returned. Returns true if the webhook is reachable and
  /// returns JSON with `status: "ok"`. On failure, sets the appropriate
  /// error and auto-pauses the target queue.
  Future<bool> _preflightCheck(String webhookUrl, String target) async {
    try {
      final Uri uri = Uri.parse(webhookUrl.trim());
      final http.Response response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));

      // Detect HTML/login page
      if (response.body.contains('<html') ||
          response.body.contains('<!DOCTYPE') ||
          response.body.contains('accounts.google.com')) {
        final String msg = 'Webhook returned HTML/login page. '
            'Ensure Apps Script is deployed with access "Anyone" and URL ends with /exec.';
        _setTargetError(target, msg);
        _pauseTarget(target);
        return false;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _setTargetError(target, 'Preflight failed: HTTP ${response.statusCode}');
        _pauseTarget(target);
        return false;
      }

      // Expect valid JSON with status: "ok"
      try {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == 'ok') {
          return true;
        }
      } catch (_) {}

      _setTargetError(target,
          'Preflight: webhook responded but not valid JSON health check');
      _pauseTarget(target);
      return false;
    } catch (error) {
      _setTargetError(target, 'Preflight error: ${_truncateError(error.toString())}');
      _pauseTarget(target);
      return false;
    }
  }

  void _setTargetError(String target, String msg) {
    if (target == 'movement') {
      _movementLastError = msg;
    } else {
      _chargingLastError = msg;
    }
    _emitStatus();
  }

  void _pauseTarget(String target) {
    if (target == 'movement') {
      _movementPaused = true;
    } else {
      _chargingPaused = true;
    }
    _emitStatus();
  }

  Future<void> enqueueMovement(Map<String, dynamic> payload) async {
    if (!_initialized) {
      await initialize();
    }
    _movementQueue.add(
      SyncQueueItem(
        id: const Uuid().v4(),
        target: 'movement',
        payload: payload,
        createdAtUtc: DateTime.now().toUtc(),
        retryCount: 0,
        nextAttemptUtc: DateTime.now().toUtc(),
      ),
    );
    await _persistQueue();
    _emitStatus();
    unawaited(_flushMovement());
  }

  Future<void> enqueueCharging(Map<String, dynamic> payload) async {
    if (!_initialized) {
      await initialize();
    }
    _chargingQueue.add(
      SyncQueueItem(
        id: const Uuid().v4(),
        target: 'charging',
        payload: payload,
        createdAtUtc: DateTime.now().toUtc(),
        retryCount: 0,
        nextAttemptUtc: DateTime.now().toUtc(),
      ),
    );
    await _persistQueue();
    _emitStatus();
    unawaited(_flushCharging());
  }

  Future<void> enqueueDelete(String tripId) async {
    if (!_initialized) {
      await initialize();
    }
    // Use movement queue for delete commands
    _movementQueue.add(
      SyncQueueItem(
        id: const Uuid().v4(),
        target: 'delete_movement',
        payload: <String, dynamic>{'trip_id': tripId},
        createdAtUtc: DateTime.now().toUtc(),
        retryCount: 0,
        nextAttemptUtc: DateTime.now().toUtc(),
      ),
    );
    await _persistQueue();
    _emitStatus();
    unawaited(_flushMovement());
  }

  // ── Pause / Resume / Retry ──

  void pauseMovement() {
    _movementPaused = true;
    _emitStatus();
  }

  void resumeMovement() {
    _movementPaused = false;
    _emitStatus();
    unawaited(_flushMovement());
  }

  Future<void> retryMovementNow() async {
    // Run preflight before retrying
    if (movementWebhookUrl.trim().isNotEmpty) {
      final bool healthy = await _preflightCheck(movementWebhookUrl, 'movement');
      if (!healthy) {
        return;
      }
    }
    for (int i = 0; i < _movementQueue.length; i++) {
      _movementQueue[i] = _movementQueue[i].copyWith(
        nextAttemptUtc: DateTime.now().toUtc(),
        retryCount: 0,
      );
    }
    _movementPaused = false;
    await _persistQueue();
    _emitStatus();
    unawaited(_flushMovement());
  }

  void pauseCharging() {
    _chargingPaused = true;
    _emitStatus();
  }

  void resumeCharging() {
    _chargingPaused = false;
    _emitStatus();
    unawaited(_flushCharging());
  }

  Future<void> retryChargingNow() async {
    // Run preflight before retrying
    if (chargingWebhookUrl.trim().isNotEmpty) {
      final bool healthy = await _preflightCheck(chargingWebhookUrl, 'charging');
      if (!healthy) {
        return;
      }
    }
    for (int i = 0; i < _chargingQueue.length; i++) {
      _chargingQueue[i] = _chargingQueue[i].copyWith(
        nextAttemptUtc: DateTime.now().toUtc(),
        retryCount: 0,
      );
    }
    _chargingPaused = false;
    await _persistQueue();
    _emitStatus();
    unawaited(_flushCharging());
  }

  Future<void> flush() => _flushAll();

  Future<void> _flushAll() async {
    await Future.wait(<Future<void>>[_flushMovement(), _flushCharging()]);
  }

  Future<void> _flushMovement() async {
    if (_movementFlushing || _movementPaused) {
      return;
    }
    if (!_initialized) {
      await initialize();
    }

    // Preflight: verify webhook is reachable before sending data
    if (movementWebhookUrl.trim().isNotEmpty) {
      final bool healthy = await _preflightCheck(movementWebhookUrl, 'movement');
      if (!healthy) {
        return;
      }
    }

    _movementFlushing = true;
    _emitStatus();
    try {
      while (_movementQueue.isNotEmpty && !_movementPaused) {
        final DateTime now = DateTime.now().toUtc();
        if (_movementQueue.first.nextAttemptUtc.isAfter(now)) {
          break;
        }

        // Handle delete_movement items one at a time
        if (_movementQueue.first.target == 'delete_movement') {
          final SyncQueueItem item = _movementQueue.first;
          final bool ok = await _sendDeleteMovement(item);
          if (ok) {
            _movementQueue.removeAt(0);
            _movementLastSuccessUtc = DateTime.now().toUtc();
            _movementLastError = null;
            await _persistQueue();
            _emitStatus();
            continue;
          }
          final int nextRetry = item.retryCount + 1;
          final int waitSeconds = min(300, 1 << min(8, nextRetry));
          _movementQueue[0] = item.copyWith(
            retryCount: nextRetry,
            nextAttemptUtc: DateTime.now().toUtc().add(
              Duration(seconds: waitSeconds),
            ),
          );
          await _persistQueue();
          _emitStatus();
          break;
        }

        final List<SyncQueueItem> batch = <SyncQueueItem>[];
        while (batch.length < 20 &&
            batch.length < _movementQueue.length &&
            !_movementQueue[batch.length].nextAttemptUtc.isAfter(now)) {
          batch.add(_movementQueue[batch.length]);
        }

        if (batch.isEmpty) {
          break;
        }

        final int accepted = await _sendBatchMovement(batch);
        if (accepted > 0) {
          _movementQueue.removeRange(0, accepted);
          _movementLastSuccessUtc = DateTime.now().toUtc();
          _movementLastError = null;
          await _persistQueue();
          _emitStatus();
          continue;
        }

        final SyncQueueItem first = _movementQueue.first;
        final int nextRetry = first.retryCount + 1;
        final int waitSeconds = min(300, 1 << min(8, nextRetry));
        _movementQueue[0] = first.copyWith(
          retryCount: nextRetry,
          nextAttemptUtc: DateTime.now().toUtc().add(
            Duration(seconds: waitSeconds),
          ),
        );
        await _persistQueue();
        _emitStatus();
        break;
      }
    } finally {
      _movementFlushing = false;
      _emitStatus();
    }
  }

  Future<void> _flushCharging() async {
    if (_chargingFlushing || _chargingPaused) {
      return;
    }
    if (!_initialized) {
      await initialize();
    }

    // Preflight: verify webhook is reachable before sending data
    if (chargingWebhookUrl.trim().isNotEmpty) {
      final bool healthy = await _preflightCheck(chargingWebhookUrl, 'charging');
      if (!healthy) {
        return;
      }
    }

    _chargingFlushing = true;
    _emitStatus();
    try {
      while (_chargingQueue.isNotEmpty && !_chargingPaused) {
        final DateTime now = DateTime.now().toUtc();
        final SyncQueueItem item = _chargingQueue.first;
        if (item.nextAttemptUtc.isAfter(now)) {
          break;
        }

        final bool ok = await _sendSingleCharging(item);
        if (ok) {
          _chargingQueue.removeAt(0);
          _chargingLastSuccessUtc = DateTime.now().toUtc();
          _chargingLastError = null;
          await _persistQueue();
          _emitStatus();
          continue;
        }

        final int nextRetry = item.retryCount + 1;
        final int waitSeconds = min(300, 1 << min(8, nextRetry));
        _chargingQueue[0] = item.copyWith(
          retryCount: nextRetry,
          nextAttemptUtc: DateTime.now().toUtc().add(
            Duration(seconds: waitSeconds),
          ),
        );
        await _persistQueue();
        _emitStatus();
        break;
      }
    } finally {
      _chargingFlushing = false;
      _emitStatus();
    }
  }

  Future<int> _sendBatchMovement(List<SyncQueueItem> batch) async {
    final String endpoint = movementWebhookUrl;
    if (endpoint.isEmpty) {
      _movementLastError = 'Movement webhook URL is empty';
      return 0;
    }

    try {
      final Map<String, dynamic> wrapper = <String, dynamic>{
        'target': 'movement',
        'key': driveWebhookApiKey,
        'records': batch.map((SyncQueueItem item) => item.payload).toList(),
      };
      final Uri uri = _withApiKeyQuery(Uri.parse(endpoint));
      final http.Response response = await _postJsonFollowingRedirect(
        uri: uri,
        body: jsonEncode(wrapper),
        timeout: const Duration(seconds: 12),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map) {
            final String s = decoded['status'] as String? ?? '';
            final int acceptedRaw = (decoded['accepted'] as num?)?.toInt() ?? 0;
            final int accepted = min(batch.length, max(0, acceptedRaw));
            if (s == 'ok') {
              _movementLastError = null;
              return accepted;
            }
          }
        } catch (_) {}
      }

      _movementLastError =
          'Movement batch fail (HTTP ${response.statusCode}): ${_truncateError(response.body)}';
      // Auto-pause if webhook misconfigured (HTML response)
      if (_isHtmlResponse(response.body)) {
        _movementPaused = true;
        _movementLastError = 'Webhook returned HTML. Auto-paused. '
            'Check deployment (access "Anyone", URL /exec), then Retry.';
      }
      return 0;
    } catch (error) {
      _movementLastError = 'Movement batch error: ${_truncateError(error.toString())}';
      // Auto-pause on webhook config errors (HTML detection etc.)
      if (error.toString().contains('HTML instead of JSON')) {
        _movementPaused = true;
      }
      return 0;
    }
  }

  Future<bool> _sendSingleCharging(SyncQueueItem item) async {
    final String endpoint = chargingWebhookUrl;
    if (endpoint.isEmpty) {
      _chargingLastError = 'Charging webhook URL is empty';
      return false;
    }

    try {
      final Map<String, dynamic> wrapper = <String, dynamic>{
        'target': 'charging',
        'key': driveWebhookApiKey,
        'record': item.payload,
      };
      final Uri uri = _withApiKeyQuery(Uri.parse(endpoint));
      final http.Response response = await _postJsonFollowingRedirect(
        uri: uri,
        body: jsonEncode(wrapper),
        timeout: const Duration(seconds: 8),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map) {
            final String s = decoded['status'] as String? ?? '';
            if (s == 'ok') {
              _chargingLastError = null;
              return true;
            }
          }
        } catch (_) {}
        _chargingLastError =
            'Charging response invalid: ${_truncateError(response.body)}';
        return false;
      }

      _chargingLastError =
          'HTTP ${response.statusCode} on charging: ${_truncateError(response.body)}';
      if (_isHtmlResponse(response.body)) {
        _chargingPaused = true;
        _chargingLastError = 'Webhook returned HTML. Auto-paused. '
            'Check deployment (access "Anyone", URL /exec), then Retry.';
      }
      return false;
    } catch (error) {
      _chargingLastError = 'Charging error: ${_truncateError(error.toString())}';
      if (error.toString().contains('HTML instead of JSON')) {
        _chargingPaused = true;
      }
      return false;
    }
  }

  Future<bool> _sendDeleteMovement(SyncQueueItem item) async {
    final String endpoint = movementWebhookUrl;
    if (endpoint.isEmpty) {
      _movementLastError = 'Movement webhook URL is empty';
      return false;
    }

    try {
      final Map<String, dynamic> wrapper = <String, dynamic>{
        'target': 'delete_movement',
        'key': driveWebhookApiKey,
        'trip_id': item.payload['trip_id'],
      };
      final Uri uri = _withApiKeyQuery(Uri.parse(endpoint));
      final http.Response response = await _postJsonFollowingRedirect(
        uri: uri,
        body: jsonEncode(wrapper),
        timeout: const Duration(seconds: 12),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map) {
            final String s = decoded['status'] as String? ?? '';
            if (s == 'ok') {
              _movementLastError = null;
              return true;
            }
          }
        } catch (_) {}
      }

      _movementLastError =
          'Delete fail (HTTP ${response.statusCode}): ${_truncateError(response.body)}';
      return false;
    } catch (error) {
      _movementLastError = 'Delete error: ${_truncateError(error.toString())}';
      return false;
    }
  }

  Uri _withApiKeyQuery(Uri uri) {
    if (driveWebhookApiKey.isEmpty) {
      return uri;
    }
    final Map<String, String> query = <String, String>{
      ...uri.queryParameters,
      'key': driveWebhookApiKey,
    };
    return uri.replace(queryParameters: query);
  }

  /// POST to the Apps Script `/exec` URL and follow redirects correctly.
  ///
  /// Google Apps Script returns a 302 redirect to `script.googleusercontent.com`
  /// which only accepts GET (serving the JSON response). Manually re-POSTing to
  /// that URL causes HTTP 405. The fix: follow 301/302/303 with GET; only
  /// re-POST for 307/308 (which preserve the method per RFC 7538).
  Future<http.Response> _postJsonFollowingRedirect({
    required Uri uri,
    required String body,
    required Duration timeout,
  }) async {
    Uri currentUri = uri;
    for (int i = 0; i < 5; i += 1) {
      final http.Response response = await _client
          .post(
            currentUri,
            headers: <String, String>{
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(timeout);

      if (!<int>[301, 302, 303, 307, 308].contains(response.statusCode)) {
        // Detect HTML body indicating Drive/login page (not a valid webhook response)
        if (response.body.contains('<html') || response.body.contains('<!DOCTYPE')) {
          throw Exception(
            'Webhook returned HTML instead of JSON. '
            'Ensure the Apps Script Web App is deployed with access "Anyone" '
            'and the URL ends with /exec.',
          );
        }
        return response;
      }

      final String? location = response.headers['location'];
      if (location == null || location.isEmpty) {
        return response;
      }
      currentUri = currentUri.resolve(location);

      // 301/302/303 → follow with GET (standard browser behavior, Apps Script expects this)
      if (<int>[301, 302, 303].contains(response.statusCode)) {
        final http.Response getResponse = await _client
            .get(currentUri)
            .timeout(timeout);
        return getResponse;
      }
      // 307/308 → re-POST with same body (loop continues)
    }

    // Fallback: final attempt as GET (most likely a redirect chain)
    return _client.get(currentUri).timeout(timeout);
  }

  String _truncateError(String message) {
    final String compact = message
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (compact.length > 120) {
      return '${compact.substring(0, 120)}...';
    }
    return compact;
  }

  bool _isHtmlResponse(String body) {
    return body.contains('<html') ||
        body.contains('<!DOCTYPE') ||
        body.contains('accounts.google.com');
  }

  Future<void> _persistQueue() async {
    await _persistence.saveSyncQueue(<SyncQueueItem>[
      ..._movementQueue,
      ..._chargingQueue,
    ]);
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
