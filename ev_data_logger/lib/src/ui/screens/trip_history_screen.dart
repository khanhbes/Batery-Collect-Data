import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/trip_providers.dart';
import '../../models/trip_history_item.dart';
import 'trip_detail_screen.dart';

class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(tripHistoryProvider);

    return Stack(
      children: <Widget>[
        historyAsync.when(
          data: (List<TripHistoryItem> items) {
            if (items.isEmpty) {
              return const Center(child: Text('No trips recorded yet.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final TripHistoryItem item = items[index];

                return Card(
                  child: ListTile(
                    title: Text('Trip ${item.tripId}'),
                    subtitle: Text(
                      '${DateFormat('yyyy-MM-dd HH:mm:ss').format(item.startTimeUtc.toLocal())}\n'
                      'SoC ${item.startSoc}% -> ${item.endSoc}% | Distance ${item.totalDistanceKm.toStringAsFixed(2)} km\n'
                      'Avg ${item.avgSpeedKmh.toStringAsFixed(1)} km/h | Max ${item.maxSpeedKmh.toStringAsFixed(1)} km/h',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TripDetailScreen(item: item),
                        ),
                      );
                    },
                    onLongPress: () async {
                      final String path = await ref
                          .read(tripControllerProvider.notifier)
                          .masterCsvPath();
                      if (await File(path).exists()) {
                        await SharePlus.instance.share(
                          ShareParams(files: <XFile>[XFile(path)]),
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, _) => Center(child: Text(error.toString())),
        ),
      ],
    );
  }
}
