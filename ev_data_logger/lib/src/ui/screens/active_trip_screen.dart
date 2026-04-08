import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/trip_providers.dart';
import '../widgets/end_trip_dialog.dart';

class ActiveTripScreen extends ConsumerWidget {
  const ActiveTripScreen({super.key, this.onTripEnded});

  final VoidCallback? onTripEnded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripState = ref.watch(tripLiveProvider);

    final telemetry = tripState.latestTelemetry;

    return Padding(
      padding: const EdgeInsets.all(16),
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
          Text('Distance: ${tripState.totalDistanceKm.toStringAsFixed(3)} km'),
          Text('Speed: ${tripState.liveSpeedKmh.toStringAsFixed(2)} km/h'),
          const SizedBox(height: 12),
          Text(
            'Timestamp: ${telemetry?.timestampUtc.toIso8601String() ?? '-'}',
          ),
          Text('Latitude: ${telemetry?.latitude.toStringAsFixed(6) ?? '-'}'),
          Text('Longitude: ${telemetry?.longitude.toStringAsFixed(6) ?? '-'}'),
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
          const Spacer(),
          SizedBox(
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
        ],
      ),
    );
  }
}
