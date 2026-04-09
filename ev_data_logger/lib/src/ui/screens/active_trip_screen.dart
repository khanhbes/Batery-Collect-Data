import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/trip_providers.dart';
import '../widgets/route_line_view.dart';
import '../widgets/end_trip_dialog.dart';

class ActiveTripScreen extends ConsumerWidget {
  const ActiveTripScreen({super.key, this.onTripEnded});

  final VoidCallback? onTripEnded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripState = ref.watch(tripLiveProvider);

    final telemetry = tripState.latestTelemetry;

    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Trip ID: ${tripState.session?.tripId ?? '-'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Text('Elapsed: ${tripState.elapsed.inSeconds}s'),
                Text('Samples: ${tripState.sampleCount}'),
                Text(
                  'Distance: ${tripState.totalDistanceKm.toStringAsFixed(3)} km',
                ),
                Text(
                  'Speed: ${tripState.liveSpeedKmh.toStringAsFixed(2)} km/h',
                ),
                Text(
                  'Vehicle: ${tripState.session?.vehicleType ?? telemetry?.vehicleType ?? '-'}',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: tripState.routePoints.length < 2
                          ? const Center(
                              child: Text(
                                'Route line will appear while moving.',
                              ),
                            )
                          : RouteLineView(points: tripState.routePoints),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Timestamp: ${telemetry?.timestampUtc.toIso8601String() ?? '-'}',
                ),
                Text(
                  'Latitude: ${telemetry?.latitude.toStringAsFixed(6) ?? '-'}',
                ),
                Text(
                  'Longitude: ${telemetry?.longitude.toStringAsFixed(6) ?? '-'}',
                ),
                Text(
                  'Altitude (m): ${telemetry?.altitudeM.toStringAsFixed(2) ?? '-'}',
                ),
                Text(
                  'Acceleration (m/s2): ${telemetry?.accelerationMs2.toStringAsFixed(3) ?? '-'}',
                ),
                Text('Start SoC: ${telemetry?.startSoc ?? '-'}'),
                Text('End SoC: ${telemetry?.endSoc?.toString() ?? '-'}'),
                Text(
                  'Payload (kg): ${telemetry?.payloadKg.toStringAsFixed(1) ?? '-'}',
                ),
                Text(
                  'Ambient Temp (C): ${telemetry?.ambientTempC?.toStringAsFixed(1) ?? '-'}',
                ),
                Text('Weather: ${telemetry?.weatherCondition ?? '-'}'),
                const SizedBox(height: 14),
                if (tripState.errorMessage != null)
                  Text(
                    'Error: ${tripState.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Debug Console'),
                  subtitle: Text('${tripState.debugLogs.length} logs'),
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      height: 180,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF08131A),
                        border: Border.all(color: const Color(0xFF56B6FF)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: tripState.debugLogs.isEmpty
                          ? const Center(
                              child: Text(
                                'No debug logs yet',
                                style: TextStyle(
                                  color: Color(0xFFBFD8EA),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : Scrollbar(
                              child: ListView.builder(
                                reverse: true,
                                itemCount: tripState.debugLogs.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final String line =
                                      tripState.debugLogs[tripState
                                              .debugLogs
                                              .length -
                                          1 -
                                          index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      line,
                                      style: const TextStyle(
                                        color: Color(0xFFE8F4FF),
                                        fontFamily: 'monospace',
                                        fontSize: 11.5,
                                        height: 1.25,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.stop_circle),
              label: const Text('End Trip'),
              onPressed: tripState.isTracking
                  ? () async {
                      final int? endSoc = await showDialog<int>(
                        context: context,
                        builder: (_) => const EndTripDialog(),
                      );

                      if (endSoc == null) {
                        return;
                      }

                      await ref
                          .read(tripControllerProvider.notifier)
                          .stopTrip(endSoc: endSoc);
                      ref.invalidate(tripHistoryProvider);
                      onTripEnded?.call();
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
