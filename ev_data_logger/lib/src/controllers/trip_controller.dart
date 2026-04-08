import 'dart:math';
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../models/telemetry_live_snapshot.dart';
import '../models/trip_history_item.dart';
import '../models/trip_session.dart';
import '../models/weather_snapshot.dart';
import '../services/background_tracking_service.dart';
import '../services/csv_service.dart';
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

  @override
  TripState build() {
    _locationService = ref.read(locationServiceProvider);
    _weatherService = ref.read(weatherServiceProvider);
    _backgroundService = ref.read(backgroundServiceProvider);
    _csvService = ref.read(csvServiceProvider);
    _persistenceService = ref.read(tripPersistenceServiceProvider);

    ref.onDispose(() {
      _telemetrySub?.cancel();
    });

    return TripState.initial();
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
    final Position current = await _locationService.getCurrentPosition();
    final DateTime now = DateTime.now().toUtc();
    final String tripId = _buildTripId(now);

    final WeatherSnapshot? weather = await _weatherService.fetchCurrent(
      current.latitude,
      current.longitude,
    );

    final WeatherSnapshot resolvedWeather =
        weather ??
        const WeatherSnapshot(condition: 'unknown', ambientTempC: null);

    final file = await _csvService.createTempFile(tripId);

    final TripSession session = TripSession(
      tripId: tripId,
      startSoc: startSoc,
      payloadKg: payloadKg,
      startTimeUtc: now,
      tempCsvPath: file.path,
      weatherCondition: resolvedWeather.condition,
      ambientTempC: resolvedWeather.ambientTempC,
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
      clearErrorMessage: true,
    );

    await _backgroundService.startTrip(session);
    _listenTelemetry();
    await _backgroundService.syncTripState();
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
      clearErrorMessage: true,
    );

    _listenTelemetry();
    await _backgroundService.syncTripState();
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

    final file = await _csvService.finalizeTrip(
      tempCsvPath: session.tempCsvPath,
      tripId: session.tripId,
      startSoc: session.startSoc,
      endSoc: endSoc,
    );
    final masterFile = await _csvService.appendTripToMaster(file);

    final DateTime endedUtc = DateTime.now().toUtc();
    final int durationSec = endedUtc.difference(session.startTimeUtc).inSeconds;
    final double totalDistanceKm =
        (stopPayload['distance_km'] as num?)?.toDouble() ??
        state.totalDistanceKm;

    await _persistenceService.appendHistory(
      TripHistoryItem(
        tripId: session.tripId,
        csvPath: file.path,
        startSoc: session.startSoc,
        endSoc: endSoc,
        payloadKg: session.payloadKg,
        startTimeUtc: session.startTimeUtc,
        endTimeUtc: endedUtc,
        durationSec: durationSec,
        totalDistanceKm: totalDistanceKm,
      ),
    );

    await _persistenceService.clearActiveTrip();

    state = state.copyWith(
      isTracking: false,
      clearSession: true,
      clearLatestTelemetry: true,
      lastExportedCsvPath: file.path,
      masterCsvPath: masterFile.path,
      totalDistanceKm: totalDistanceKm,
    );

    return file.path;
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

  void _listenTelemetry() {
    _telemetrySub?.cancel();
    _telemetrySub = _backgroundService.telemetryStream().listen((
      Map<String, dynamic> event,
    ) {
      final String type = event['event'] as String;
      if (type == 'telemetry.tick') {
        final TelemetryLiveSnapshot telemetry = TelemetryLiveSnapshot.fromMap(
          event,
        );
        state = state.copyWith(
          latestTelemetry: telemetry,
          elapsed: Duration(seconds: telemetry.elapsedSec),
          sampleCount: telemetry.sampleCount,
          liveSpeedKmh: telemetry.speedKmh,
          totalDistanceKm: telemetry.distanceKm,
          clearErrorMessage: true,
        );
        return;
      }

      if (type == 'telemetry.error') {
        state = state.copyWith(errorMessage: event['message'] as String?);
      }
    });
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
