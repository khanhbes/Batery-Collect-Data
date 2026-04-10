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
  late Future<String> _chargingCsvFuture;
  ProviderSubscription<String?>? _masterPathSub;
  ProviderSubscription<String?>? _chargingPathSub;

  @override
  void initState() {
    super.initState();
    _masterCsvFuture = _loadMasterCsvPath();
    _chargingCsvFuture = _loadChargingCsvPath();
    _masterPathSub = ref.listenManual<String?>(
      tripLiveProvider.select((TripState state) => state.masterCsvPath),
      (String? previous, String? next) {
        if (previous == next || next == null) {
          return;
        }
        _refreshMasterCsvPath();
      },
    );
    _chargingPathSub = ref.listenManual<String?>(
      chargingLiveProvider.select(
        (chargingState) => chargingState.chargingLogCsvPath,
      ),
      (String? previous, String? next) {
        if (previous == next || next == null) {
          return;
        }
        _refreshChargingCsvPath();
      },
    );
  }

  @override
  void dispose() {
    _masterPathSub?.close();
    _chargingPathSub?.close();
    super.dispose();
  }

  Future<String> _loadMasterCsvPath() async {
    try {
      return await ref.read(tripControllerProvider.notifier).masterCsvPath();
    } catch (_) {
      return '';
    }
  }

  Future<String> _loadChargingCsvPath() async {
    try {
      return await ref.read(chargingControllerProvider.notifier).chargingLogCsvPath();
    } catch (_) {
      return '';
    }
  }

  Future<void> _refreshMasterCsvPath() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _masterCsvFuture = _loadMasterCsvPath();
    });
  }

  Future<void> _refreshChargingCsvPath() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _chargingCsvFuture = _loadChargingCsvPath();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripLiveProvider);
    final String? masterPathFromState = ref.watch(
      tripLiveProvider.select((TripState state) => state.masterCsvPath),
    );
    final String? chargingPathFromState = ref.watch(
      chargingLiveProvider.select(
        (chargingState) => chargingState.chargingLogCsvPath,
      ),
    );

    return FutureBuilder<String>(
      future: _masterCsvFuture,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final String? masterPath = masterPathFromState ?? snapshot.data;

        return FutureBuilder<String>(
          future: _chargingCsvFuture,
          builder: (BuildContext context, AsyncSnapshot<String> chargingSnap) {
            final String? chargingPath =
                chargingPathFromState ?? chargingSnap.data;

            return RefreshIndicator(
              onRefresh: () async {
                await _refreshMasterCsvPath();
                await _refreshChargingCsvPath();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Movement Sync',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text('Pending: ${tripState.movementPendingCount}'),
                          Text(
                            'Status: ${tripState.movementSyncPaused ? 'Paused' : tripState.movementSyncInProgress ? 'Uploading...' : 'Idle'}',
                          ),
                          Text(
                            'Last success: ${tripState.movementLastSuccessUtc?.toIso8601String() ?? '-'}',
                          ),
                          Text(
                            'Last error: ${tripState.movementLastError ?? '-'}',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              TextButton.icon(
                                onPressed: () {
                                  final ctrl = ref.read(tripControllerProvider.notifier);
                                  if (tripState.movementSyncPaused) {
                                    ctrl.resumeMovementSync();
                                  } else {
                                    ctrl.pauseMovementSync();
                                  }
                                },
                                icon: Icon(tripState.movementSyncPaused ? Icons.play_arrow : Icons.pause),
                                label: Text(tripState.movementSyncPaused ? 'Resume' : 'Pause'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () {
                                  ref.read(tripControllerProvider.notifier).retryMovementSync();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Charging Sync',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text('Pending: ${tripState.chargingPendingCount}'),
                          Text(
                            'Status: ${tripState.chargingSyncPaused ? 'Paused' : tripState.chargingSyncInProgress ? 'Uploading...' : 'Idle'}',
                          ),
                          Text(
                            'Last success: ${tripState.chargingLastSuccessUtc?.toIso8601String() ?? '-'}',
                          ),
                          Text(
                            'Last error: ${tripState.chargingLastError ?? '-'}',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              TextButton.icon(
                                onPressed: () {
                                  final ctrl = ref.read(tripControllerProvider.notifier);
                                  if (tripState.chargingSyncPaused) {
                                    ctrl.resumeChargingSync();
                                  } else {
                                    ctrl.pauseChargingSync();
                                  }
                                },
                                icon: Icon(tripState.chargingSyncPaused ? Icons.play_arrow : Icons.pause),
                                label: Text(tripState.chargingSyncPaused ? 'Resume' : 'Pause'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () {
                                  ref.read(tripControllerProvider.notifier).retryChargingSync();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      const Text(
                        'Export Center',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Refresh export paths',
                        onPressed: () async {
                          await _refreshMasterCsvPath();
                          await _refreshChargingCsvPath();
                        },
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Master CSV: ${masterPath ?? 'Loading...'}'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: masterPath == null
                          ? null
                          : () async {
                              if (await File(masterPath).exists()) {
                                await SharePlus.instance.share(
                                  ShareParams(
                                    files: <XFile>[XFile(masterPath)],
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share Master CSV'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Active Trip Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: tripState.tempCsvPath == null
                          ? null
                          : () async {
                              final File f = File(tripState.tempCsvPath!);
                              if (await f.exists()) {
                                await SharePlus.instance.share(
                                  ShareParams(
                                    files: <XFile>[XFile(tripState.tempCsvPath!)],
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.location_on),
                      label: const Text('Share Trip Detail CSV (Current)'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('Charging Log CSV: ${chargingPath ?? 'Loading...'}'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: chargingPath == null
                          ? null
                          : () async {
                              if (await File(chargingPath).exists()) {
                                await SharePlus.instance.share(
                                  ShareParams(
                                    files: <XFile>[XFile(chargingPath)],
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.bolt),
                      label: const Text('Share Charging Log CSV'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
