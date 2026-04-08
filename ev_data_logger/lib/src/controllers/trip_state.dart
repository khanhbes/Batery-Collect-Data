import '../models/trip_session.dart';
import '../models/telemetry_live_snapshot.dart';

class TripState {
  const TripState({
    required this.isTracking,
    required this.session,
    required this.elapsed,
    required this.totalDistanceKm,
    required this.liveSpeedKmh,
    required this.sampleCount,
    required this.latestTelemetry,
    required this.lastExportedCsvPath,
    required this.masterCsvPath,
    required this.errorMessage,
  });

  factory TripState.initial() {
    return const TripState(
      isTracking: false,
      session: null,
      elapsed: Duration.zero,
      totalDistanceKm: 0,
      liveSpeedKmh: 0,
      sampleCount: 0,
      latestTelemetry: null,
      lastExportedCsvPath: null,
      masterCsvPath: null,
      errorMessage: null,
    );
  }

  final bool isTracking;
  final TripSession? session;
  final Duration elapsed;
  final double totalDistanceKm;
  final double liveSpeedKmh;
  final int sampleCount;
  final TelemetryLiveSnapshot? latestTelemetry;
  final String? lastExportedCsvPath;
  final String? masterCsvPath;
  final String? errorMessage;

  TripState copyWith({
    bool? isTracking,
    TripSession? session,
    Duration? elapsed,
    double? totalDistanceKm,
    double? liveSpeedKmh,
    int? sampleCount,
    TelemetryLiveSnapshot? latestTelemetry,
    String? lastExportedCsvPath,
    String? masterCsvPath,
    String? errorMessage,
    bool clearSession = false,
    bool clearLatestTelemetry = false,
    bool clearLastExportedCsvPath = false,
    bool clearMasterCsvPath = false,
    bool clearErrorMessage = false,
  }) {
    return TripState(
      isTracking: isTracking ?? this.isTracking,
      session: clearSession ? null : session ?? this.session,
      elapsed: elapsed ?? this.elapsed,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      liveSpeedKmh: liveSpeedKmh ?? this.liveSpeedKmh,
      sampleCount: sampleCount ?? this.sampleCount,
      latestTelemetry: clearLatestTelemetry
          ? null
          : latestTelemetry ?? this.latestTelemetry,
      lastExportedCsvPath: clearLastExportedCsvPath
          ? null
          : lastExportedCsvPath ?? this.lastExportedCsvPath,
      masterCsvPath: clearMasterCsvPath
          ? null
          : masterCsvPath ?? this.masterCsvPath,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
