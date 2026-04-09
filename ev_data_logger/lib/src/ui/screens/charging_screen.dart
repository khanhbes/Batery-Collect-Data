import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../controllers/trip_providers.dart';
import '../../models/charging_session_item.dart';
import 'charging_detail_screen.dart';

class ChargingScreen extends ConsumerWidget {
  const ChargingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargingState = ref.watch(chargingLiveProvider);
    final active = chargingState.activeChargingSession;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  active == null
                      ? 'No active charging session'
                      : 'Charging in progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (active != null) ...<Widget>[
                  Text('Charge ID: ${active.chargeId}'),
                  Text('Start SoC: ${active.startSoc}%'),
                  Text(
                    'Started: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(active.startTimestampUtc.toLocal())}',
                  ),
                  Text(
                    'Location: ${active.latitude.toStringAsFixed(6)}, ${active.longitude.toStringAsFixed(6)}',
                  ),
                  Text(
                    'Ambient Temp: ${active.ambientTempC?.toStringAsFixed(1) ?? '-'} C',
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: chargingState.isBusy || active != null
                            ? null
                            : () async {
                                final int? startSoc = await _showSocDialog(
                                  context,
                                  title: 'Start Charging',
                                  label: 'Start SoC (%)',
                                );
                                if (startSoc == null) {
                                  return;
                                }
                                try {
                                  await ref
                                      .read(chargingControllerProvider.notifier)
                                      .startCharging(startSoc: startSoc);
                                } catch (error) {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              },
                        child: const Text('Start Charging'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: chargingState.isBusy || active == null
                            ? null
                            : () async {
                                final int? endSoc = await _showSocDialog(
                                  context,
                                  title: 'End Charging',
                                  label: 'End SoC (%)',
                                );
                                if (endSoc == null) {
                                  return;
                                }
                                try {
                                  await ref
                                      .read(chargingControllerProvider.notifier)
                                      .endCharging(endSoc: endSoc);
                                } catch (error) {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              },
                        child: const Text('End Charging'),
                      ),
                    ),
                  ],
                ),
                if (chargingState.chargingErrorMessage != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    chargingState.chargingErrorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Recent Charging Sessions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (chargingState.chargingHistory.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No charging sessions recorded yet.'),
            ),
          ),
        ...chargingState.chargingHistory
            .take(10)
            .map(
              (ChargingSessionItem item) => Card(
                child: ListTile(
                  title: Text('Charge ${item.chargeId}'),
                  subtitle: Text(
                    '${DateFormat('yyyy-MM-dd HH:mm:ss').format(item.startTimestampUtc.toLocal())}\n'
                    'SoC ${item.startSoc}% -> ${item.endSoc?.toString() ?? '-'}%',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChargingDetailScreen(item: item),
                      ),
                    );
                  },
                ),
              ),
            ),
      ],
    );
  }

  Future<int?> _showSocDialog(
    BuildContext context, {
    required String title,
    required String label,
  }) async {
    final TextEditingController controller = TextEditingController();
    final int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(int.tryParse(controller.text)),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }
}
