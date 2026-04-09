import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/trip_providers.dart';
import '../../controllers/trip_state.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  late Future<String> _masterCsvFuture;
  ProviderSubscription<String?>? _masterPathSub;

  @override
  void initState() {
    super.initState();
    _masterCsvFuture = _loadMasterCsvPath();
    _masterPathSub = ref.listenManual<String?>(
      tripLiveProvider.select((TripState state) => state.masterCsvPath),
      (String? previous, String? next) {
        if (previous == next || next == null) {
          return;
        }
        _refreshMasterCsvPath();
      },
    );
  }

  @override
  void dispose() {
    _masterPathSub?.close();
    super.dispose();
  }

  Future<String> _loadMasterCsvPath() {
    return ref.read(tripControllerProvider.notifier).masterCsvPath();
  }

  Future<void> _refreshMasterCsvPath() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _masterCsvFuture = _loadMasterCsvPath();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? masterPathFromState = ref.watch(
      tripLiveProvider.select((TripState state) => state.masterCsvPath),
    );

    return FutureBuilder<String>(
      future: _masterCsvFuture,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final String? masterPath = masterPathFromState ?? snapshot.data;

        return RefreshIndicator(
          onRefresh: _refreshMasterCsvPath,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text(
                    'Export Center',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh export paths',
                    onPressed: _refreshMasterCsvPath,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Master CSV: ${masterPath ?? 'Loading...'}'),
              const SizedBox(height: 18),
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
