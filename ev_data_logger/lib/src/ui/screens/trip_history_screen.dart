import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/trip_providers.dart';
import '../../models/trip_history_item.dart';

class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({
    super.key,
    this.highlightCsvPath,
    this.showShareLatestButton = false,
  });

  final String? highlightCsvPath;
  final bool showShareLatestButton;

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
                final bool highlighted = item.csvPath == highlightCsvPath;

                return Card(
                  color: highlighted ? Colors.teal.shade50 : null,
                  child: ListTile(
                    title: Text('Trip ${item.tripId}'),
                    subtitle: Text(
                      '${DateFormat('yyyy-MM-dd HH:mm:ss').format(item.startTimeUtc.toLocal())}\n'
                      'SoC ${item.startSoc}% -> ${item.endSoc}% | '
                      'Distance ${item.totalDistanceKm.toStringAsFixed(2)} km',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () async {
                        await SharePlus.instance.share(
                          ShareParams(files: <XFile>[XFile(item.csvPath)]),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, _) => Center(child: Text(error.toString())),
        ),
        if (showShareLatestButton && highlightCsvPath != null)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () async {
                if (highlightCsvPath != null &&
                    await File(highlightCsvPath!).exists()) {
                  await SharePlus.instance.share(
                    ShareParams(files: <XFile>[XFile(highlightCsvPath!)]),
                  );
                }
              },
              icon: const Icon(Icons.ios_share),
              label: const Text('Share Latest'),
            ),
          ),
      ],
    );
  }
}
