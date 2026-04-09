import 'package:ev_data_logger/src/controllers/trip_providers.dart';
import 'package:ev_data_logger/src/controllers/trip_state.dart';
import 'package:ev_data_logger/src/models/route_point.dart';
import 'package:ev_data_logger/src/models/trip_history_item.dart';
import 'package:ev_data_logger/src/ui/screens/active_trip_screen.dart';
import 'package:ev_data_logger/src/ui/screens/trip_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Debug panel shows appended log lines', (
    WidgetTester tester,
  ) async {
    const TripState state = TripState(
      isTracking: false,
      session: null,
      elapsed: Duration.zero,
      totalDistanceKm: 0,
      liveSpeedKmh: 0,
      sampleCount: 0,
      latestTelemetry: null,
      routePoints: <RoutePoint>[],
      debugLogs: <String>['first log', 'second log'],
      isPassengerOn: false,
      syncPendingCount: 0,
      syncLastSuccessUtc: null,
      syncLastError: null,
      syncInProgress: false,
      masterCsvPath: null,
      errorMessage: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripLiveProvider.overrideWithValue(state)],
        child: const MaterialApp(home: Scaffold(body: ActiveTripScreen())),
      ),
    );

    await tester.ensureVisible(find.text('Debug Console'));
    await tester.tap(find.text('Debug Console'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('second log'), findsOneWidget);
    expect(find.text('first log'), findsOneWidget);
  });

  testWidgets('History tap navigates to trip detail', (
    WidgetTester tester,
  ) async {
    final TripHistoryItem item = TripHistoryItem(
      tripId: 'trip_abc',
      vehicleType: 'Electric Vehicle',
      startTimeUtc: DateTime.parse('2026-01-01T00:00:00Z'),
      endTimeUtc: DateTime.parse('2026-01-01T00:10:00Z'),
      durationSec: 600,
      startSoc: 90,
      endSoc: 84,
      socDelta: 6,
      payloadKg: 100,
      sampleCount: 30,
      totalDistanceKm: 8.2,
      avgSpeedKmh: 32.8,
      maxSpeedKmh: 55,
      avgAccelerationMs2: 0.2,
      maxAccelerationMs2: 0.8,
      minAltitudeM: 5,
      maxAltitudeM: 20,
      startLatitude: 10.0,
      startLongitude: 106.0,
      endLatitude: 10.1,
      endLongitude: 106.1,
      ambientTempC: 30,
      weatherCondition: 'Clouds',
      routePreview: const <RoutePoint>[
        RoutePoint(latitude: 10.0, longitude: 106.0),
        RoutePoint(latitude: 10.1, longitude: 106.1),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripHistoryProvider.overrideWith(
            (ref) async => <TripHistoryItem>[item],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TripHistoryScreen())),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Trip trip_abc'));
    await tester.pumpAndSettle();

    expect(find.text('Trip Detail trip_abc'), findsOneWidget);
  });
}
