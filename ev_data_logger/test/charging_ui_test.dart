import 'package:ev_data_logger/src/controllers/charging_state.dart';
import 'package:ev_data_logger/src/controllers/trip_providers.dart';
import 'package:ev_data_logger/src/controllers/trip_state.dart';
import 'package:ev_data_logger/src/models/charging_session_item.dart';
import 'package:ev_data_logger/src/ui/screens/charging_screen.dart';
import 'package:ev_data_logger/src/ui/screens/export_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Charging screen shows current error message', (
    WidgetTester tester,
  ) async {
    const ChargingState state = ChargingState(
      activeChargingSession: null,
      chargingHistory: <ChargingSessionItem>[],
      chargingLogCsvPath: 'C:/temp/Charging_log.csv',
      chargingErrorMessage: 'End SoC must be between start SoC and 100.',
      isBusy: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chargingLiveProvider.overrideWithValue(state)],
        child: const MaterialApp(home: Scaffold(body: ChargingScreen())),
      ),
    );

    expect(
      find.text('End SoC must be between start SoC and 100.'),
      findsOneWidget,
    );
  });

  testWidgets('Export screen shows charging log share action', (
    WidgetTester tester,
  ) async {
    const ChargingState chargingState = ChargingState(
      activeChargingSession: null,
      chargingHistory: <ChargingSessionItem>[],
      chargingLogCsvPath: 'C:/temp/Charging_log.csv',
      chargingErrorMessage: null,
      isBusy: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chargingLiveProvider.overrideWithValue(chargingState),
          tripLiveProvider.overrideWithValue(TripState.initial()),
        ],
        child: const MaterialApp(home: Scaffold(body: ExportScreen())),
      ),
    );

    // Pump multiple times to allow async FutureBuilders to resolve
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Scroll down to reach the charging log section
    await tester.scrollUntilVisible(
      find.text('Share Charging Log CSV'),
      200,
    );
    await tester.pump();

    expect(find.text('Share Charging Log CSV'), findsOneWidget);
  });
}
