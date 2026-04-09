import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_history_item.dart';
import '../services/background_tracking_service.dart';
import '../services/csv_service.dart';
import '../services/drive_sync_service.dart';
import '../services/location_service.dart';
import '../services/trip_persistence_service.dart';
import '../services/weather_service.dart';
import 'charging_controller.dart';
import 'charging_state.dart';
import 'trip_controller.dart';
import 'trip_state.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

final backgroundServiceProvider = Provider<BackgroundTrackingService>((ref) {
  return BackgroundTrackingService();
});

final csvServiceProvider = Provider<CsvService>((ref) {
  return CsvService();
});

final tripPersistenceServiceProvider = Provider<TripPersistenceService>((ref) {
  return TripPersistenceService();
});

final driveSyncServiceProvider = Provider<DriveSyncService>((ref) {
  final DriveSyncService service = DriveSyncService(
    ref.read(tripPersistenceServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final driveSyncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final DriveSyncService service = ref.read(driveSyncServiceProvider);
  return service.statusStream;
});

final tripControllerProvider = NotifierProvider<TripController, TripState>(
  TripController.new,
);

final tripLiveProvider = Provider<TripState>((ref) {
  return ref.watch(tripControllerProvider);
});

final tripHistoryProvider = FutureProvider<List<TripHistoryItem>>((ref) {
  return ref.watch(tripControllerProvider.notifier).loadHistory();
});

final chargingControllerProvider =
    NotifierProvider<ChargingController, ChargingState>(
      ChargingController.new,
    );

final chargingLiveProvider = Provider<ChargingState>((ref) {
  return ref.watch(chargingControllerProvider);
});
