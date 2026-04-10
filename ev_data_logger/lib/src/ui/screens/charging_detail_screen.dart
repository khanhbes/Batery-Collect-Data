import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/charging_session_item.dart';

class ChargingDetailScreen extends StatelessWidget {
  const ChargingDetailScreen({super.key, required this.item});

  final ChargingSessionItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Charging Detail ${item.chargeId}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _metric(
            'Start Timestamp',
            DateFormat(
              'yyyy-MM-dd HH:mm:ss',
            ).format(item.startTimestampUtc.toLocal()),
          ),
          _metric(
            'End Timestamp',
            item.endTimestampUtc == null
                ? '-'
                : DateFormat(
                    'yyyy-MM-dd HH:mm:ss',
                  ).format(item.endTimestampUtc!.toLocal()),
          ),
          _metric('Start SoC', '${item.startSoc}%'),
          _metric('End SoC', item.endSoc == null ? '-' : '${item.endSoc}%'),
          _metric('Latitude', item.latitude.toStringAsFixed(6)),
          _metric('Longitude', item.longitude.toStringAsFixed(6)),
          _metric(
            'Ambient Temp (C)',
            item.ambientTempC?.toStringAsFixed(1) ?? '-',
          ),
          if (item.rawDataPath != null) ...<Widget>[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final File f = File(item.rawDataPath!);
                  if (await f.exists()) {
                    await SharePlus.instance.share(
                      ShareParams(
                        files: <XFile>[XFile(item.rawDataPath!)],
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.ios_share),
                label: const Text('Share Charging Log CSV'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(flex: 5, child: Text(value)),
        ],
      ),
    );
  }
}
