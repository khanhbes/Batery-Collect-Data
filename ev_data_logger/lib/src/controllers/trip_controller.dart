import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../config/app_info.dart';
import '../models/route_point.dart';
import '../models/telemetry_live_snapshot.dart';
import '../models/trip_history_item.dart';
import '../models/trip_session.dart';
import '../models/weather_snapshot.dart';
import '../services/background_tracking_service.dart';
import '../services/csv_service.dart';
import '../services/drive_sync_service.dart';
import '../services/location_service.dart';
import '../services/trip_persistence_service.dart';
import '../services/weather_service.dart';
import 'trip_providers.dart';
import 'trip_state.dart';

class TripController extends Notifier<TripState> {
  late final LocationService _locationService;
  late final WeatherService _weatherService;
  late final BackgroundTrackingService _backgroundService;
  late final CsvService _csvService;
  late final TripPersistenceService _persistenceService;
  late final DriveSyncService _driveSyncService;

  StreamSubscription<SyncStatus>? _syncStatusSub;

  @override
  TripState build() {
    _locationService = ref.read(locationServiceProvider);
    _weatherService = ref.read(weatherServiceProvider);
    _backgroundService = ref.read(backgroundServiceProvider);
    _csvService = ref.read(csvServiceProvider);
    _persistenceService = ref.read(tripPersistenceServiceProvider);
    _driveSyncService = ref.read(driveSyncServiceProvider);

    unawaited(_driveSyncService.initialize());
    _syncStatusSub?.cancel();
    _syncStatusSub = _driveSyncService.statusStream.listen((SyncStatus s) {
      state = state.copyWith(
        movementPendingCount: s.movement.pendingCount,
        movementSyncInProgress: s.movement.isFlushing,
        movementSyncPaused: s.movement.isPaused,
        movementLastSuccessUtc: s.movement.lastSuccessUtc,
        clearMovementLastSuccessUtc: s.movement.lastSuccessUtc == null,
        movementLastError: s.movement.lastError,
        clearMovementLastError: s.movement.lastError == null,
        chargingPendingCount: s.charging.pendingCount,
        chargingSyncInProgress: s.charging.isFlushing,
        chargingSyncPaused: s.charging.isPaused,
        chargingLastSuccessUtc: s.charging.lastSuccessUtc,
        clearChargingLastSuccessUtc: s.charging.lastSuccessUtc == null,
        chargingLastError: s.charging.lastError,
        clearChargingLastError: s.charging.lastError == null,
      );
    });
    final SyncStatus initialSync = _driveSyncService.status;

    ref.onDispose(() {
      _telemetrySub?.cancel();
      _syncStatusSub?.cancel();
    });

    return TripState.initial().copyWith(
      movementPendingCount: initialSync.movement.pendingCount,
      movementSyncInProgress: initialSync.movement.isFlushing,
      movementSyncPaused: initialSync.movement.isPaused,
      movementLastSuccessUtc: initialSync.movement.lastSuccessUtc,
      movementLastError: initialSync.movement.lastError,
      chargingPendingCount: initialSync.charging.pendingCount,
      chargingSyncInProgress: initialSync.charging.isFlushing,
      chargingSyncPaused: initialSync.charging.isPaused,
      chargingLastSuccessUtc: initialSync.charging.lastSuccessUtc,
      chargingLastError: initialSync.charging.lastError,
    );
  }

  StreamSubscription<Map<String, dynamic>>? _telemetrySub;

  Future<TripSession?> getRecoverableTrip() async {
    return _persistenceService.loadActiveTrip();
  }

  Future<void> startTrip({
    required int startSoc,
    required double payloadKg,
  }) async {
    if (startSoc < 0 || startSoc > 100) {
      throw Exception('start_soc must be in range 0..100.');
    }
    if (payloadKg < 0) {
      throw Exception('payload_kg must be >= 0.');
    }

    await _locationService.ensurePermissions();
    final Position? seedPosition = await _locationService
        .getCurrentPositionWithFallback(timeout: const Duration(seconds: 5));
    final DateTime now = DateTime.now().toUtc();
    final String tripId = _buildTripId(now);

    final file = await _csvService.createTempFile(tripId);

    final TripSession session = TripSession(
      tripId: tripId,
      vehicleType: evVehicleType,
      startSoc: startSoc,
      payloadKg: payloadKg,
      startTimeUtc: now,
      tempCsvPath: file.path,
      weatherCondition: 'unknown',
      ambientTempC: null,
    );

    await _persistenceService.saveActiveTrip(session);

    state = state.copyWith(
      isTracking: true,
      session: session,
      elapsed: Duration.zero,
      sampleCount: 0,
      totalDistanceKm: 0,
      liveSpeedKmh: 0,
      clearLatestTelemetry: true,
      clearRoutePoints: true,
      clearDebugLogs: true,
      isPassengerOn: false,
      clearErrorMessage: true,
    );
    _appendDebug(
      'Start trip requested: vehicle=${session.vehicleType} start_soc=$startSoc payload=$payloadKg',
    );

    _listenTelemetry();
    await _backgroundService.startTrip(session);
    await _backgroundService.syncTripState();

    // ── Seed movement record: enqueue sample_count=0 immediately at Start ──
    unawaited(
      _driveSyncService.enqueueMovement(<String, dynamic>{
        'trip_id': session.tripId,
        'timestamp_utc': now.toIso8601String(),
        'elapsed_sec': 0,
        'sample_count': 0,
        'speed_kmh': 0,
        'accel_ms2': 0,
        'distance_km': 0,
        'latitude': seedPosition?.latitude ?? 0,
        'longitude': seedPosition?.longitude ?? 0,
        'altitude_m': seedPosition?.altitude ?? 0,
        'start_soc': startSoc,
        'end_soc': '',
        'payload_kg': payloadKg,
        'effective_payload_kg': payloadKg,
        'passenger_on': false,
        'ambient_temp_c': 0.0,
        'weather_condition': 'unknown',
      }),
    );

    unawaited(_enrichWeatherAsync(session, seedPosition: seedPosition));
  }

  Future<void> _enrichWeatherAsync(
    TripSession session, {
    Position? seedPosition,
  }) async {
    try {
      final Position? position =
          seedPosition ??
          await _locationService.getCurrentPositionWithFallback(
            timeout: const Duration(seconds: 4),
          );
      if (position == null) {
        _appendDebug('Weather enrichment skipped: no GPS fix yet');
        return;
      }

      final WeatherSnapshot? weather = await _weatherService.fetchCurrent(
        position.latitude,
        position.longitude,
      );
      if (weather == null) {
        return;
      }

      final TripSession? active = await _persistenceService.loadActiveTrip();
      if (active == null || active.tripId != session.tripId) {
        return;
      }

      final TripSession updated = TripSession(
        tripId: active.tripId,
        vehicleType: active.vehicleType,
        startSoc: active.startSoc,
        payloadKg: active.payloadKg,
        startTimeUtc: active.startTimeUtc,
        tempCsvPath: active.tempCsvPath,
        weatherCondition: weather.condition,
        ambientTempC: weather.ambientTempC,
      );

      await _persistenceService.saveActiveTrip(updated);
      await _backgroundService.updateTripMetadata(
        tripId: updated.tripId,
        weatherCondition: updated.weatherCondition,
        ambientTempC: updated.ambientTempC,
        effectivePayloadKg: _effectivePayloadKg(),
        passengerOn: state.isPassengerOn,
      );

      if (state.session?.tripId == updated.tripId) {
        state = state.copyWith(session: updated);
      }
      _appendDebug(
        'Weather updated async: ${updated.weatherCondition} ${updated.ambientTempC?.toStringAsFixed(1) ?? '-'}C',
      );
    } catch (error) {
      _appendDebug('Weather enrichment failed: $error');
    }
  }

  Future<void> resumeTrip() async {
    final TripSession? session = await _persistenceService.loadActiveTrip();
    if (session == null) {
      throw Exception('No recoverable trip found.');
    }

    state = state.copyWith(
      isTracking: true,
      session: session,
      elapsed: DateTime.now().toUtc().difference(session.startTimeUtc),
      clearLatestTelemetry: true,
      clearRoutePoints: true,
      clearErrorMessage: true,
    );
    _appendDebug('Resume trip requested: ${session.tripId}');

    // Attach listener first so we don't miss the first tick.
    _listenTelemetry();

    // Smart resume: if the BG isolate lost the trip (process killed / OOM),
    // re-send the full trip.start payload instead of only syncing.
    final bool tripActive = await _backgroundService.isTripActive();
    if (tripActive) {
      await _backgroundService.syncTripState();
      _appendDebug('Resume: BG isolate active — synced');
    } else {
      await _backgroundService.ensureTripRunning(session);
      _appendDebug('Resume: BG isolate had no trip — re-sent trip.start');
    }
  }

  Future<String> stopTrip({required int endSoc}) async {
    if (endSoc < 0 || endSoc > 100) {
      throw Exception('end_soc must be in range 0..100.');
    }

    final TripSession? session = state.session;
    if (session == null) {
      throw Exception('No active trip to stop.');
    }

    final Map<String, dynamic> stopPayload = await _backgroundService
        .stopTrip();
    // Cancel the telemetry subscription before we clear state.
    _telemetrySub?.cancel();
    _syncStatusSub?.cancel();
    _telemetrySub = null;

    final DateTime endedUtc = DateTime.now().toUtc();
    final int durationSec = endedUtc.difference(session.startTimeUtc).inSeconds;

    final _TempTripStats tempStats = await _readTempTripStats(
      session.tempCsvPath,
    );

    // Priority: stopPayload (if valid) > state > csv-derived
    final int stopSamples = (stopPayload['sample_count'] as num?)?.toInt() ?? 0;
    final int stateSamples = state.sampleCount;
    final int csvSamples = tempStats.sampleCountFromCsv;
    final int sampleCount = stopSamples > 0
        ? stopSamples
        : (stateSamples > 0 ? stateSamples : csvSamples);

    final double stopDist = (stopPayload['distance_km'] as num?)?.toDouble() ?? 0;
    final double stateDist = state.totalDistanceKm;
    final double csvDist = tempStats.distanceKmFromRoute;
    final double totalDistanceKm = stopDist > 0
        ? stopDist
        : (stateDist > 0 ? stateDist : csvDist);
    final List<RoutePoint> routePreview = _downsampleRoute(
      tempStats.routePoints,
      maxPoints: 140,
    );

    // Move temp CSV to permanent raw path instead of deleting
    final String? rawDataPath = await _csvService.moveToRawPath(
      session.tempCsvPath,
      session.tripId,
    );

    final TripHistoryItem summary = TripHistoryItem(
      tripId: session.tripId,
      vehicleType: session.vehicleType,
      startTimeUtc: session.startTimeUtc,
      endTimeUtc: endedUtc,
      durationSec: durationSec,
      startSoc: session.startSoc,
      endSoc: endSoc,
      socDelta: session.startSoc - endSoc,
      payloadKg: session.payloadKg,
      sampleCount: sampleCount,
      totalDistanceKm: totalDistanceKm,
      avgSpeedKmh: tempStats.avgSpeedKmh,
      maxSpeedKmh: tempStats.maxSpeedKmh,
      avgAccelerationMs2: tempStats.avgAccelerationMs2,
      maxAccelerationMs2: tempStats.maxAccelerationMs2,
      minAltitudeM: tempStats.minAltitudeM,
      maxAltitudeM: tempStats.maxAltitudeM,
      startLatitude: tempStats.startLatitude,
      startLongitude: tempStats.startLongitude,
      endLatitude: tempStats.endLatitude,
      endLongitude: tempStats.endLongitude,
      ambientTempC: session.ambientTempC,
      weatherCondition: session.weatherCondition,
      routePreview: routePreview,
      rawDataPath: rawDataPath,
    );

    final File masterFile = await _csvService.appendTripSummary(summary);

    await _persistenceService.appendHistory(summary);

    await _persistenceService.clearActiveTrip();

    state = state.copyWith(
      isTracking: false,
      clearSession: true,
      clearLatestTelemetry: true,
      clearRoutePoints: true,
      masterCsvPath: masterFile.path,
      totalDistanceKm: totalDistanceKm,
    );
    _appendDebug('Trip finalized: ${session.tripId} -> ${masterFile.path}');

    return masterFile.path;
  }

  Future<String> endRecoveredTrip({required int endSoc}) async {
    final TripSession? session = await _persistenceService.loadActiveTrip();
    if (session == null) {
      throw Exception('No recoverable trip found.');
    }

    if (!state.isTracking) {
      state = state.copyWith(isTracking: true, session: session);
    }

    return stopTrip(endSoc: endSoc);
  }

  Future<String> masterCsvPath() async {
    final File master = await _csvService.getMasterFile();
    return master.path;
  }

  Future<List<TripHistoryItem>> loadHistory() {
    return _persistenceService.loadHistory();
  }

  Future<void> deleteTrip(String tripId) async {
    final List<TripHistoryItem> history = await _persistenceService.loadHistory();
    final TripHistoryItem? item = history.cast<TripHistoryItem?>().firstWhere(
      (TripHistoryItem? e) => e?.tripId == tripId,
      orElse: () => null,
    );

    // Delete local raw CSV file
    if (item?.rawDataPath != null) {
      await _csvService.deleteRawFile(item!.rawDataPath!);
    }

    // Remove from local history JSON
    await _persistenceService.deleteHistoryItem(tripId);

    // Enqueue delete command to sync with Google Sheet
    unawaited(_driveSyncService.enqueueDelete(tripId));
  }

  void pauseMovementSync() => _driveSyncService.pauseMovement();
  void resumeMovementSync() => _driveSyncService.resumeMovement();
  Future<void> retryMovementSync() => _driveSyncService.retryMovementNow();
  void pauseChargingSync() => _driveSyncService.pauseCharging();
  void resumeChargingSync() => _driveSyncService.resumeCharging();
  Future<void> retryChargingSync() => _driveSyncService.retryChargingNow();

  void _listenTelemetry() {
    _telemetrySub?.cancel();
    _telemetrySub = _backgroundService.telemetryStream().listen((
      Map<String, dynamic> event,
    ) {
      final String? type = event['event'] as String?;
      if (type == null) {
        _appendDebug('ERROR: telemetry event has no type');
        return;
      }
      if (type == 'telemetry.tick') {
        final TelemetryLiveSnapshot telemetry;
        try {
          telemetry = TelemetryLiveSnapshot.fromMap(event);
        } catch (e) {
          _appendDebug('ERROR: malformed tick payload — $e');
          return;
        }
        final List<RoutePoint> nextRoute =
            List<RoutePoint>.from(state.routePoints)..add(
              RoutePoint(
                latitude: telemetry.latitude,
                longitude: telemetry.longitude,
              ),
            );
        if (nextRoute.length > 1200) {
          nextRoute.removeRange(0, nextRoute.length - 1200);
        }

        state = state.copyWith(
          latestTelemetry: telemetry,
          routePoints: nextRoute,
          elapsed: Duration(seconds: telemetry.elapsedSec),
          sampleCount: telemetry.sampleCount,
          liveSpeedKmh: telemetry.speedKmh,
          totalDistanceKm: telemetry.distanceKm,
          clearErrorMessage: true,
        );

        // Throttle movement sync: enqueue every 5 samples to avoid flooding Google Sheets.
        // CSV still records every 1s tick.
        final TripSession? session = state.session;
        if (session != null && telemetry.sampleCount % 5 == 0) {
          unawaited(
            _driveSyncService.enqueueMovement(<String, dynamic>{
              'trip_id': session.tripId,
              'timestamp_utc': telemetry.timestampUtc.toIso8601String(),
              'elapsed_sec': telemetry.elapsedSec,
              'sample_count': telemetry.sampleCount,
              'speed_kmh': telemetry.speedKmh,
              'accel_ms2': telemetry.accelerationMs2,
              'distance_km': telemetry.distanceKm,
              'latitude': telemetry.latitude,
              'longitude': telemetry.longitude,
              'altitude_m': telemetry.altitudeM,
              'start_soc': telemetry.startSoc,
              'end_soc': telemetry.endSoc ?? '',
              'payload_kg': telemetry.payloadKg,
              'effective_payload_kg': telemetry.effectivePayloadKg,
              'passenger_on': telemetry.passengerOn,
              'ambient_temp_c': telemetry.ambientTempC ?? 0.0,
              'weather_condition': telemetry.weatherCondition,
            }),
          );
        }
        return;
      }

      if (type == 'telemetry.error') {
        final String message =
            (event['message'] as String?) ?? 'Unknown telemetry error';
        _appendDebug('ERROR: $message');
        state = state.copyWith(errorMessage: message);
        return;
      }

      if (type == 'telemetry.debug') {
        final String message = (event['message'] as String?) ?? 'Debug event';
        _appendDebug(message);
        return;
      }

      if (type == 'telemetry.started') {
        final String tripId = (event['trip_id'] as String?) ?? 'unknown';
        _appendDebug('Background ACK start received for $tripId');
        return;
      }

      if (type == 'telemetry.heartbeat') {
        final int elapsedSec = (event['elapsed_sec'] as num?)?.toInt() ?? 0;
        final int samples = (event['sample_count'] as num?)?.toInt() ?? state.sampleCount;
        final double distKm = (event['distance_km'] as num?)?.toDouble() ?? state.totalDistanceKm;
        state = state.copyWith(
          elapsed: Duration(seconds: elapsedSec),
          sampleCount: samples,
          totalDistanceKm: distKm,
        );
        return;
      }

      if (type == 'telemetry.stopped') {
        final int sampleCount =
            (event['sample_count'] as num?)?.toInt() ?? state.sampleCount;
        final double distanceKm =
            (event['distance_km'] as num?)?.toDouble() ?? state.totalDistanceKm;
        _appendDebug(
          'Background tracking stopped (samples=$sampleCount distance=${distanceKm.toStringAsFixed(3)} km)',
        );
        state = state.copyWith(
          isTracking: false,
          clearSession: true,
          sampleCount: sampleCount,
          totalDistanceKm: distanceKm,
        );
        return;
      }

      _appendDebug('Unknown telemetry event: $type');
    });
  }

  void _appendDebug(String message) {
    final String log = '[${DateTime.now().toUtc().toIso8601String()}] $message';
    final List<String> next = List<String>.from(state.debugLogs)..add(log);
    if (next.length > 150) {
      next.removeRange(0, next.length - 150);
    }
    state = state.copyWith(debugLogs: next);
  }

  Future<void> setPassengerOn(bool value) async {
    final TripSession? session = state.session;
    if (session == null) {
      return;
    }

    state = state.copyWith(isPassengerOn: value);
    final double effectivePayloadKg = _effectivePayloadKg();
    await _backgroundService.updateTripMetadata(
      tripId: session.tripId,
      weatherCondition: session.weatherCondition,
      ambientTempC: session.ambientTempC,
      effectivePayloadKg: effectivePayloadKg,
      passengerOn: value,
    );
    _appendDebug(
      'Passenger ${value ? 'ON' : 'OFF'}; effective payload=${effectivePayloadKg.toStringAsFixed(1)} kg',
    );
  }

  double _effectivePayloadKg() {
    final TripSession? session = state.session;
    if (session == null) {
      return 0;
    }
    return session.payloadKg + (state.isPassengerOn ? 65 : 0);
  }

  Future<_TempTripStats> _readTempTripStats(String tempCsvPath) async {
    final File tempFile = File(tempCsvPath);
    if (!await tempFile.exists()) {
      return _TempTripStats.empty();
    }

    int count = 0;
    double speedSum = 0;
    double maxSpeed = 0;
    double accSum = 0;
    double maxAcc = 0;
    double? minAlt;
    double? maxAlt;
    final List<RoutePoint> route = <RoutePoint>[];
    double routeDistanceKm = 0;

    await for (final String line
        in tempFile
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('timestamp,')) {
        continue;
      }

      final List<String> cols = trimmed.split(',');
      if (cols.length < 12) {
        continue;
      }

      final double? lat = double.tryParse(cols[2]);
      final double? lon = double.tryParse(cols[3]);
      final double speed = double.tryParse(cols[4]) ?? 0;
      final double alt = double.tryParse(cols[5]) ?? 0;
      final double acc = double.tryParse(cols[6]) ?? 0;

      if (lat != null && lon != null) {
        // Calculate distance from previous point
        if (route.isNotEmpty) {
          final RoutePoint prev = route.last;
          if (!(lat == prev.latitude && lon == prev.longitude)) {
            routeDistanceKm += Geolocator.distanceBetween(
              prev.latitude, prev.longitude, lat, lon,
            ) / 1000;
          }
        }
        route.add(RoutePoint(latitude: lat, longitude: lon));
      }

      speedSum += speed;
      if (speed > maxSpeed) {
        maxSpeed = speed;
      }

      accSum += acc;
      if (acc > maxAcc) {
        maxAcc = acc;
      }

      // Filter altitude for summary: only consider valid range
      if (alt >= -100 && alt <= 2000) {
        minAlt = minAlt == null ? alt : min(minAlt, alt);
        maxAlt = maxAlt == null ? alt : max(maxAlt, alt);
      }
      count += 1;
    }

    if (count == 0 || route.isEmpty) {
      return _TempTripStats.empty();
    }

    final RoutePoint start = route.first;
    final RoutePoint end = route.last;
    return _TempTripStats(
      avgSpeedKmh: speedSum / count,
      maxSpeedKmh: maxSpeed,
      avgAccelerationMs2: accSum / count,
      maxAccelerationMs2: maxAcc,
      minAltitudeM: minAlt ?? 0,
      maxAltitudeM: maxAlt ?? 0,
      startLatitude: start.latitude,
      startLongitude: start.longitude,
      endLatitude: end.latitude,
      endLongitude: end.longitude,
      routePoints: route,
      sampleCountFromCsv: count,
      distanceKmFromRoute: routeDistanceKm,
    );
  }

  List<RoutePoint> _downsampleRoute(
    List<RoutePoint> points, {
    required int maxPoints,
  }) {
    if (points.length <= maxPoints) {
      return points;
    }
    final double step = points.length / maxPoints;
    final List<RoutePoint> reduced = <RoutePoint>[];
    for (int i = 0; i < maxPoints; i++) {
      reduced.add(points[(i * step).floor()]);
    }
    return reduced;
  }

  String _buildTripId(DateTime startedUtc) {
    final String stamp = startedUtc
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final String suffix = const Uuid().v4().substring(0, 8);
    return '${stamp}_${Random().nextInt(9999)}_$suffix';
  }
}

class _TempTripStats {
  const _TempTripStats({
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.avgAccelerationMs2,
    required this.maxAccelerationMs2,
    required this.minAltitudeM,
    required this.maxAltitudeM,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    required this.routePoints,
    required this.sampleCountFromCsv,
    required this.distanceKmFromRoute,
  });

  factory _TempTripStats.empty() {
    return const _TempTripStats(
      avgSpeedKmh: 0,
      maxSpeedKmh: 0,
      avgAccelerationMs2: 0,
      maxAccelerationMs2: 0,
      minAltitudeM: 0,
      maxAltitudeM: 0,
      startLatitude: 0,
      startLongitude: 0,
      endLatitude: 0,
      endLongitude: 0,
      routePoints: <RoutePoint>[],
      sampleCountFromCsv: 0,
      distanceKmFromRoute: 0,
    );
  }

  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double avgAccelerationMs2;
  final double maxAccelerationMs2;
  final double minAltitudeM;
  final double maxAltitudeM;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final List<RoutePoint> routePoints;
  final int sampleCountFromCsv;
  final double distanceKmFromRoute;
}
