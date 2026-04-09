import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/trip_history_item.dart';
import '../widgets/route_line_view.dart';

class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key, required this.item});

  final TripHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Trip Detail ${item.tripId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Started: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(item.startTimeUtc.toLocal())}',
            ),
            Text(
              'Ended: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(item.endTimeUtc.toLocal())}',
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 180,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: item.routePreview.length < 2
                      ? const Center(child: Text('No route preview available.'))
                      : RouteLineView(points: item.routePreview),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _metric('Vehicle Type', item.vehicleType),
            _metric('Duration', '${item.durationSec}s'),
            _metric('Start SoC', '${item.startSoc}%'),
            _metric('End SoC', '${item.endSoc}%'),
            _metric('SoC Delta', '${item.socDelta}%'),
            _metric('Payload (kg)', item.payloadKg.toStringAsFixed(1)),
            _metric('Sample Count', '${item.sampleCount}'),
            _metric(
              'Total Distance (km)',
              item.totalDistanceKm.toStringAsFixed(3),
            ),
            _metric('Avg Speed (km/h)', item.avgSpeedKmh.toStringAsFixed(2)),
            _metric('Max Speed (km/h)', item.maxSpeedKmh.toStringAsFixed(2)),
            _metric(
              'Avg Acceleration (m/s2)',
              item.avgAccelerationMs2.toStringAsFixed(3),
            ),
            _metric(
              'Max Acceleration (m/s2)',
              item.maxAccelerationMs2.toStringAsFixed(3),
            ),
            _metric('Min Altitude (m)', item.minAltitudeM.toStringAsFixed(2)),
            _metric('Max Altitude (m)', item.maxAltitudeM.toStringAsFixed(2)),
            _metric(
              'Start Lat/Lon',
              '${item.startLatitude.toStringAsFixed(6)}, ${item.startLongitude.toStringAsFixed(6)}',
            ),
            _metric(
              'End Lat/Lon',
              '${item.endLatitude.toStringAsFixed(6)}, ${item.endLongitude.toStringAsFixed(6)}',
            ),
            _metric(
              'Ambient Temp (C)',
              item.ambientTempC?.toStringAsFixed(1) ?? '-',
            ),
            _metric('Weather', item.weatherCondition),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 6, child: Text(value)),
        ],
      ),
    );
  }
}
