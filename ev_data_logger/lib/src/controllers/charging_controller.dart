import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../models/charging_session_item.dart';
import '../models/weather_snapshot.dart';
import '../services/csv_service.dart';
import '../services/drive_sync_service.dart';
import '../services/location_service.dart';
import '../services/trip_persistence_service.dart';
import '../services/weather_service.dart';
import 'charging_state.dart';
import 'trip_providers.dart';

class ChargingController extends Notifier<ChargingState> {
  late final LocationService _locationService;
  late final WeatherService _weatherService;
  late final CsvService _csvService;
  late final TripPersistenceService _persistenceService;
  late final DriveSyncService _driveSyncService;

  @override
  ChargingState build() {
    _locationService = ref.read(locationServiceProvider);
    _weatherService = ref.read(weatherServiceProvider);
    _csvService = ref.read(csvServiceProvider);
    _persistenceService = ref.read(tripPersistenceServiceProvider);
    _driveSyncService = ref.read(driveSyncServiceProvider);
    unawaited(_driveSyncService.initialize());
    unawaited(_restoreState());
    return ChargingState.initial();
  }

  Future<void> _restoreState() async {
    final ChargingSessionItem? active = await _persistenceService
        .loadActiveCharging();
    final List<ChargingSessionItem> history = await _persistenceService
        .loadChargingHistory();
    final String path = await chargingLogCsvPath();

    state = state.copyWith(
      activeChargingSession: active,
      chargingHistory: history,
      chargingLogCsvPath: path,
      clearChargingErrorMessage: true,
    );
  }

  Future<void> startCharging({required int startSoc}) async {
    if (startSoc < 0 || startSoc > 100) {
      throw Exception('Start SoC must be between 0 and 100.');
    }
    if (state.activeChargingSession != null) {
      throw Exception('A charging session is already active.');
    }

    state = state.copyWith(isBusy: true, clearChargingErrorMessage: true);
    try {
      await _locationService.ensurePermissions();
      final Position? position = await _locationService
          .getCurrentPositionWithFallback(timeout: const Duration(seconds: 5));
      if (position == null) {
        throw Exception('Unable to determine charging location.');
      }

      final WeatherSnapshot? weather = await _weatherService.fetchCurrent(
        position.latitude,
        position.longitude,
      );
      final DateTime now = DateTime.now().toUtc();
      final ChargingSessionItem session = ChargingSessionItem(
        chargeId: _buildChargeId(now),
        startTimestampUtc: now,
        endTimestampUtc: null,
        startSoc: startSoc,
        endSoc: null,
        latitude: position.latitude,
        longitude: position.longitude,
        ambientTempC: weather?.ambientTempC,
      );

      await _persistenceService.saveActiveCharging(session);
      final String path = await chargingLogCsvPath();
      state = state.copyWith(
        activeChargingSession: session,
        chargingLogCsvPath: path,
        clearChargingErrorMessage: true,
      );
    } catch (error) {
      state = state.copyWith(chargingErrorMessage: error.toString());
      rethrow;
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<void> endCharging({required int endSoc}) async {
    final ChargingSessionItem? active =
        state.activeChargingSession ??
        await _persistenceService.loadActiveCharging();
    if (active == null) {
      throw Exception('No active charging session.');
    }
    if (endSoc < active.startSoc || endSoc > 100) {
      throw Exception('End SoC must be between start SoC and 100.');
    }

    state = state.copyWith(isBusy: true, clearChargingErrorMessage: true);
    try {
      final ChargingSessionItem completed = active.copyWith(
        endTimestampUtc: DateTime.now().toUtc(),
        endSoc: endSoc,
      );
      final int deltaSoc = (completed.endSoc ?? completed.startSoc) -
          completed.startSoc;
      final int durationSec =
          completed.endTimestampUtc?.difference(completed.startTimestampUtc).inSeconds ??
          0;
      final file = await _csvService.appendChargingSummary(completed);
      await _persistenceService.appendChargingHistory(completed);
      await _persistenceService.clearActiveCharging();
      unawaited(
        _driveSyncService.enqueueCharging(<String, dynamic>{
          'charge_id': completed.chargeId,
          'start_timestamp_utc': completed.startTimestampUtc.toIso8601String(),
          'end_timestamp_utc': completed.endTimestampUtc?.toIso8601String(),
          'start_soc': completed.startSoc,
          'end_soc': completed.endSoc,
          'delta_soc': deltaSoc,
          'duration_sec': durationSec,
          'latitude': completed.latitude,
          'longitude': completed.longitude,
          'ambient_temp_c': completed.ambientTempC,
        }),
      );

      state = state.copyWith(
        clearActiveChargingSession: true,
        chargingHistory: <ChargingSessionItem>[
          completed,
          ...state.chargingHistory,
        ],
        chargingLogCsvPath: file.path,
        clearChargingErrorMessage: true,
      );
    } catch (error) {
      state = state.copyWith(chargingErrorMessage: error.toString());
      rethrow;
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<String> chargingLogCsvPath() async {
    final file = await _csvService.getChargingLogFile();
    return file.path;
  }

  String _buildChargeId(DateTime startedUtc) {
    final String stamp = startedUtc
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final String suffix = const Uuid().v4().substring(0, 8);
    return 'charge_${stamp}_${Random().nextInt(9999)}_$suffix';
  }
}
