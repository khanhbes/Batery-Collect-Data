import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/trip_providers.dart';

class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tripLiveProvider);

    return FutureBuilder<String>(
      future: ref.read(tripControllerProvider.notifier).masterCsvPath(),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final String? masterPath = snapshot.data;
        final String? latestPath = state.lastExportedCsvPath;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Export Center',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text('Latest trip CSV: ${latestPath ?? 'Not available yet'}'),
              const SizedBox(height: 8),
              Text('Master CSV: ${masterPath ?? 'Loading...'}'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: latestPath == null
                      ? null
                      : () async {
                          if (await File(latestPath).exists()) {
                            await SharePlus.instance.share(
                              ShareParams(files: <XFile>[XFile(latestPath)]),
                            );
                          }
                        },
                  icon: const Icon(Icons.share),
                  label: const Text('Share Latest Trip CSV'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: masterPath == null
                      ? null
                      : () async {
                          if (await File(masterPath).exists()) {
                            await SharePlus.instance.share(
                              ShareParams(files: <XFile>[XFile(masterPath)]),
                            );
                          }
                        },
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share Master CSV'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
