import '../models/trip_session.dart';
import '../models/route_point.dart';
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
    required this.routePoints,
    required this.debugLogs,
    required this.isPassengerOn,
    required this.movementPendingCount,
    required this.movementSyncInProgress,
    required this.movementSyncPaused,
    required this.movementLastSuccessUtc,
    required this.movementLastError,
    required this.chargingPendingCount,
    required this.chargingSyncInProgress,
    required this.chargingSyncPaused,
    required this.chargingLastSuccessUtc,
    required this.chargingLastError,
    required this.masterCsvPath,
    required this.tempCsvPath,
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
      routePoints: <RoutePoint>[],
      debugLogs: <String>[],
      isPassengerOn: false,
      movementPendingCount: 0,
      movementSyncInProgress: false,
      movementSyncPaused: false,
      movementLastSuccessUtc: null,
      movementLastError: null,
      chargingPendingCount: 0,
      chargingSyncInProgress: false,
      chargingSyncPaused: false,
      chargingLastSuccessUtc: null,
      chargingLastError: null,
      masterCsvPath: null,
      tempCsvPath: null,
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
  final List<RoutePoint> routePoints;
  final List<String> debugLogs;
  final bool isPassengerOn;
  final int movementPendingCount;
  final bool movementSyncInProgress;
  final bool movementSyncPaused;
  final DateTime? movementLastSuccessUtc;
  final String? movementLastError;
  final int chargingPendingCount;
  final bool chargingSyncInProgress;
  final bool chargingSyncPaused;
  final DateTime? chargingLastSuccessUtc;
  final String? chargingLastError;
  final String? masterCsvPath;
  final String? tempCsvPath;
  final String? errorMessage;

  TripState copyWith({
    bool? isTracking,
    TripSession? session,
    Duration? elapsed,
    double? totalDistanceKm,
    double? liveSpeedKmh,
    int? sampleCount,
    TelemetryLiveSnapshot? latestTelemetry,
    List<RoutePoint>? routePoints,
    List<String>? debugLogs,
    bool? isPassengerOn,
    int? movementPendingCount,
    bool? movementSyncInProgress,
    bool? movementSyncPaused,
    DateTime? movementLastSuccessUtc,
    String? movementLastError,
    int? chargingPendingCount,
    bool? chargingSyncInProgress,
    bool? chargingSyncPaused,
    DateTime? chargingLastSuccessUtc,
    String? chargingLastError,
    String? masterCsvPath,
    String? tempCsvPath,
    String? errorMessage,
    bool clearSession = false,
    bool clearLatestTelemetry = false,
    bool clearRoutePoints = false,
    bool clearDebugLogs = false,
    bool clearMovementLastSuccessUtc = false,
    bool clearMovementLastError = false,
    bool clearChargingLastSuccessUtc = false,
    bool clearChargingLastError = false,
    bool clearMasterCsvPath = false,
    bool clearTempCsvPath = false,
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
      routePoints: clearRoutePoints
          ? <RoutePoint>[]
          : routePoints ?? this.routePoints,
      debugLogs: clearDebugLogs ? <String>[] : debugLogs ?? this.debugLogs,
      isPassengerOn: isPassengerOn ?? this.isPassengerOn,
      movementPendingCount: movementPendingCount ?? this.movementPendingCount,
      movementSyncInProgress: movementSyncInProgress ?? this.movementSyncInProgress,
      movementSyncPaused: movementSyncPaused ?? this.movementSyncPaused,
      movementLastSuccessUtc: clearMovementLastSuccessUtc
          ? null
          : movementLastSuccessUtc ?? this.movementLastSuccessUtc,
      movementLastError: clearMovementLastError
          ? null
          : movementLastError ?? this.movementLastError,
      chargingPendingCount: chargingPendingCount ?? this.chargingPendingCount,
      chargingSyncInProgress: chargingSyncInProgress ?? this.chargingSyncInProgress,
      chargingSyncPaused: chargingSyncPaused ?? this.chargingSyncPaused,
      chargingLastSuccessUtc: clearChargingLastSuccessUtc
          ? null
          : chargingLastSuccessUtc ?? this.chargingLastSuccessUtc,
      chargingLastError: clearChargingLastError
          ? null
          : chargingLastError ?? this.chargingLastError,
      masterCsvPath: clearMasterCsvPath
          ? null
          : masterCsvPath ?? this.masterCsvPath,
      tempCsvPath: clearTempCsvPath
          ? null
          : tempCsvPath ?? this.tempCsvPath,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
