import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_history_item.dart';
import '../services/background_tracking_service.dart';
import '../services/csv_service.dart';
import '../services/location_service.dart';
import '../services/trip_persistence_service.dart';
import '../services/weather_service.dart';
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

final tripControllerProvider = NotifierProvider<TripController, TripState>(
  TripController.new,
);

final tripLiveProvider = Provider<TripState>((ref) {
  return ref.watch(tripControllerProvider);
});

final tripHistoryProvider = FutureProvider<List<TripHistoryItem>>((ref) {
  return ref.watch(tripControllerProvider.notifier).loadHistory();
});
