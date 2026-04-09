import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../models/trip_session.dart';

StreamSubscription<Position>? _bgPositionSub;
Timer? _bgTickTimer;
Position? _bgLatestPosition;
Position? _bgPrevDistancePosition;
double _bgLastSpeedMps = 0;
double _bgDistanceKm = 0;
int _bgSampleCount = 0;
Map<String, dynamic>? _bgTrip;
bool _bgFirstFixEmitted = false;

const String _eventTick = 'telemetry.tick';
const String _eventError = 'telemetry.error';
const String _eventStopped = 'telemetry.stopped';
const String _eventDebug = 'telemetry.debug';
const String _eventStatus = 'telemetry.status';
const String _eventStarted = 'telemetry.started';

Future<void> _appendCsvLine(String filePath, List<dynamic> row) async {
  final File file = File(filePath);
  await file.writeAsString('${row.join(',')}\n', mode: FileMode.append);
}

Map<String, dynamic>? _buildTickPayload({
  required DateTime now,
  required Position position,
  required double accelerationMs2,
}) {
  final Map<String, dynamic>? trip = _bgTrip;
  if (trip == null) {
    return null;
  }

  final DateTime startUtc = DateTime.parse(
    trip['start_time_utc'] as String,
  ).toUtc();
  return <String, dynamic>{
    'timestamp': now.toIso8601String(),
    'trip_id': trip['trip_id'],
    'latitude': position.latitude,
    'longitude': position.longitude,
    'speed_kmh': position.speed * 3.6,
    'altitude_m': position.altitude,
    'acceleration_ms2': accelerationMs2,
    'start_soc': trip['start_soc'],
    'end_soc': null,
    'payload_kg': trip['payload_kg'],
    'ambient_temp_c': trip['ambient_temp_c'],
    'weather_condition': trip['weather_condition'],
    'vehicle_type': trip['vehicle_type'],
    'sample_count': _bgSampleCount,
    'elapsed_sec': max(0, now.difference(startUtc).inSeconds),
    'distance_km': _bgDistanceKm,
  };
}

void _emitError(ServiceInstance service, Object error) {
  service.invoke(_eventError, <String, dynamic>{'message': error.toString()});
}

void _emitDebug(ServiceInstance service, String message) {
  service.invoke(_eventDebug, <String, dynamic>{
    'message': message,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  });
}

Future<void> _stopTripInternals(ServiceInstance service) async {
  await _bgPositionSub?.cancel();
  _bgPositionSub = null;

  _bgTickTimer?.cancel();
  _bgTickTimer = null;

  _bgLatestPosition = null;
  _bgPrevDistancePosition = null;
  _bgLastSpeedMps = 0;

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'EV Data Logger',
      content: 'Tracking stopped',
    );
  }

  service.invoke(_eventStopped, <String, dynamic>{
    'sample_count': _bgSampleCount,
    'distance_km': _bgDistanceKm,
  });
  _emitDebug(
    service,
    'Trip stopped: samples=$_bgSampleCount distance=${_bgDistanceKm.toStringAsFixed(3)} km',
  );

  _bgTrip = null;
  _bgDistanceKm = 0;
  _bgSampleCount = 0;
}

Future<void> _startTripInternals(
  ServiceInstance service,
  Map<String, dynamic> trip,
) async {
  _bgTrip = trip;
  _bgDistanceKm = 0;
  _bgSampleCount = 0;
  _bgLastSpeedMps = 0;
  _bgPrevDistancePosition = null;
  _bgFirstFixEmitted = false;

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'EV Data Logger',
      content: 'Tracking trip ${trip['trip_id']}',
    );
  }
  _emitDebug(
    service,
    'Trip started: id=${trip['trip_id']} vehicle=${trip['vehicle_type']}',
  );
  _emitDebug(service, 'phase=start_received');
  service.invoke(_eventStarted, <String, dynamic>{
    'trip_id': trip['trip_id'],
    'received_at_utc': DateTime.now().toUtc().toIso8601String(),
  });

  await _bgPositionSub?.cancel();
  _bgPositionSub =
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen(
        (Position position) {
          if (!_bgFirstFixEmitted) {
            _bgFirstFixEmitted = true;
            _emitDebug(service, 'phase=first_fix');
          }
          final Position? prev = _bgPrevDistancePosition;
          if (prev != null) {
            _bgDistanceKm +=
                Geolocator.distanceBetween(
                  prev.latitude,
                  prev.longitude,
                  position.latitude,
                  position.longitude,
                ) /
                1000;
          }
          _bgPrevDistancePosition = position;
          _bgLatestPosition = position;
        },
        onError: (Object error) {
          _emitError(service, error);
          _emitDebug(service, 'phase=stream_error $error');
        },
      );
  _emitDebug(service, 'phase=stream_attached');

  unawaited(
    Geolocator.getLastKnownPosition().then((Position? position) {
      if (position != null && _bgLatestPosition == null) {
        _bgLatestPosition = position;
      }
    }),
  );

  _bgTickTimer?.cancel();
  _bgTickTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
    final Map<String, dynamic>? currentTrip = _bgTrip;
    final Position? position = _bgLatestPosition;
    if (currentTrip == null || position == null) {
      return;
    }

    final DateTime now = DateTime.now().toUtc();
    final double acceleration = _bgSampleCount == 0
        ? 0
        : (position.speed - _bgLastSpeedMps);
    _bgLastSpeedMps = position.speed;
    _bgSampleCount += 1;

    final Map<String, dynamic>? payload = _buildTickPayload(
      now: now,
      position: position,
      accelerationMs2: acceleration,
    );

    if (payload == null) {
      return;
    }

    try {
      await _appendCsvLine(currentTrip['temp_csv_path'] as String, <dynamic>[
        payload['timestamp'],
        payload['trip_id'],
        payload['latitude'],
        payload['longitude'],
        payload['speed_kmh'],
        payload['altitude_m'],
        payload['acceleration_ms2'],
        payload['start_soc'],
        '',
        payload['payload_kg'],
        payload['ambient_temp_c'] ?? '',
        payload['weather_condition'],
      ]);
      service.invoke(_eventTick, payload);
      if (_bgSampleCount % 20 == 0) {
        _emitDebug(
          service,
          'Tick sample=$_bgSampleCount speed=${(payload['speed_kmh'] as num).toStringAsFixed(1)} km/h',
        );
      }
    } catch (error) {
      _emitError(service, error);
    }
  });
}

@pragma('vm:entry-point')
Future<void> backgroundServiceEntryPoint(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'EV Data Logger',
      content: 'Background service ready',
    );
  }
  _emitDebug(service, 'Background service ready');

  service.on('trip.start').listen((dynamic payload) async {
    try {
      final Map<String, dynamic> trip = Map<String, dynamic>.from(
        payload as Map,
      );
      await _startTripInternals(service, trip);
    } catch (error) {
      _emitError(service, error);
    }
  });

  service.on('trip.stop').listen((_) async {
    await _stopTripInternals(service);
  });

  service.on('trip.sync').listen((_) {
    final Map<String, dynamic>? trip = _bgTrip;
    final Position? position = _bgLatestPosition;
    if (trip == null || position == null) {
      return;
    }

    final Map<String, dynamic>? payload = _buildTickPayload(
      now: DateTime.now().toUtc(),
      position: position,
      accelerationMs2: 0,
    );
    if (payload != null) {
      service.invoke(_eventTick, payload);
      _emitDebug(service, 'Trip state synced');
    }
  });

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  service.on('trip.status').listen((_) {
    service.invoke(_eventStatus, <String, dynamic>{
      'trip_active': _bgTrip != null,
      'trip_id': _bgTrip?['trip_id'],
    });
  });

  service.on('trip.update_meta').listen((dynamic payload) {
    try {
      final Map<String, dynamic> map = Map<String, dynamic>.from(
        payload as Map,
      );
      if (_bgTrip == null) {
        return;
      }
      if (map['trip_id'] != _bgTrip?['trip_id']) {
        return;
      }

      if (map.containsKey('weather_condition')) {
        _bgTrip!['weather_condition'] = map['weather_condition'];
      }
      if (map.containsKey('ambient_temp_c')) {
        _bgTrip!['ambient_temp_c'] = map['ambient_temp_c'];
      }
      _emitDebug(service, 'Trip metadata updated');
    } catch (error) {
      _emitError(service, error);
    }
  });
}

class BackgroundTrackingService {
  final FlutterBackgroundService _service = FlutterBackgroundService();

  bool _initialized = false;
  Stream<Map<String, dynamic>>? _telemetryStream;

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) {
      return;
    }

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundServiceEntryPoint,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: false,
        foregroundServiceNotificationId: 73,
        initialNotificationTitle: 'EV Data Logger',
        initialNotificationContent: 'Background service ready',
        foregroundServiceTypes: <AndroidForegroundType>[
          AndroidForegroundType.location,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: backgroundServiceEntryPoint,
        onBackground: _iosBackground,
      ),
    );

    _initialized = true;
  }

  Future<void> _ensureServiceRunning() async {
    if (!_isSupportedPlatform) {
      return;
    }
    await initialize();
    final bool running = await _service.isRunning();
    if (!running) {
      await _service.startService();
    }
  }

  Stream<Map<String, dynamic>> telemetryStream() {
    return _telemetryStream ??= Stream<Map<String, dynamic>>.multi((
      controller,
    ) {
      final List<StreamSubscription<dynamic>> subscriptions =
          <StreamSubscription<dynamic>>[];

      for (final String key in <String>[
        _eventTick,
        _eventError,
        _eventStopped,
        _eventDebug,
        _eventStarted,
      ]) {
        subscriptions.add(
          _service.on(key).listen((dynamic event) {
            final Map<String, dynamic> map = Map<String, dynamic>.from(
              (event ?? <String, dynamic>{}) as Map,
            );
            map['event'] = key;
            controller.add(map);
          }),
        );
      }

      controller.onCancel = () async {
        for (final StreamSubscription<dynamic> sub in subscriptions) {
          await sub.cancel();
        }
      };
    }).asBroadcastStream();
  }

  Future<void> startTrip(TripSession session) async {
    await _ensureServiceRunning();

    final Completer<void> started = Completer<void>();
    late final StreamSubscription<dynamic> sub;
    sub = _service.on(_eventStarted).listen((dynamic event) async {
      final Map<String, dynamic> payload = Map<String, dynamic>.from(
        (event ?? <String, dynamic>{}) as Map,
      );
      if (payload['trip_id'] == session.tripId && !started.isCompleted) {
        started.complete();
      }
      await sub.cancel();
    });

    _service.invoke('trip.start', <String, dynamic>{
      'trip_id': session.tripId,
      'start_soc': session.startSoc,
      'payload_kg': session.payloadKg,
      'ambient_temp_c': session.ambientTempC,
      'weather_condition': session.weatherCondition,
      'vehicle_type': session.vehicleType,
      'temp_csv_path': session.tempCsvPath,
      'start_time_utc': session.startTimeUtc.toIso8601String(),
    });

    try {
      await started.future.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      await sub.cancel();
    }
  }

  Future<void> updateTripMetadata({
    required String tripId,
    required String weatherCondition,
    required double? ambientTempC,
  }) async {
    await _ensureServiceRunning();
    _service.invoke('trip.update_meta', <String, dynamic>{
      'trip_id': tripId,
      'weather_condition': weatherCondition,
      'ambient_temp_c': ambientTempC,
    });
  }

  Future<Map<String, dynamic>> stopTrip() async {
    if (!_isSupportedPlatform) {
      return <String, dynamic>{'sample_count': 0, 'distance_km': 0.0};
    }

    await _ensureServiceRunning();

    final Completer<Map<String, dynamic>> completer =
        Completer<Map<String, dynamic>>();
    late final StreamSubscription<dynamic> sub;
    sub = _service.on(_eventStopped).listen((dynamic event) async {
      final Map<String, dynamic> payload = Map<String, dynamic>.from(
        (event ?? <String, dynamic>{}) as Map,
      );
      if (!completer.isCompleted) {
        completer.complete(payload);
      }
      await sub.cancel();
    });

    _service.invoke('trip.stop');
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () async {
        await sub.cancel();
        return <String, dynamic>{'sample_count': 0, 'distance_km': 0.0};
      },
    );
  }

  Future<void> syncTripState() async {
    await _ensureServiceRunning();
    _service.invoke('trip.sync');
  }

  /// Returns true if the background service process is running.
  Future<bool> isServiceRunning() async {
    if (!_isSupportedPlatform) return false;
    return _service.isRunning();
  }

  /// Returns true if the background isolate has an active trip loaded.
  /// Queries the isolate directly; times out after 3 s → returns false.
  Future<bool> isTripActive() async {
    if (!_isSupportedPlatform) return false;
    final bool running = await _service.isRunning();
    if (!running) return false;

    final Completer<bool> completer = Completer<bool>();
    late final StreamSubscription<dynamic> sub;
    sub = _service.on(_eventStatus).listen((dynamic event) async {
      final Map<String, dynamic> payload = Map<String, dynamic>.from(
        (event ?? <String, dynamic>{}) as Map,
      );
      if (!completer.isCompleted) {
        completer.complete((payload['trip_active'] as bool?) == true);
      }
      await sub.cancel();
    });
    _service.invoke('trip.status');
    return completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () async {
        await sub.cancel();
        return false;
      },
    );
  }

  /// Ensures the background service is running and tracking [session].
  /// If the isolate has lost the trip (e.g. process was killed), re-sends
  /// the full trip.start command instead of only syncing.
  Future<void> ensureTripRunning(TripSession session) async {
    await _ensureServiceRunning();
    final bool active = await isTripActive();
    if (!active) {
      await startTrip(session);
    }
  }

  Future<void> stopService() async {
    if (!_isSupportedPlatform) {
      return;
    }

    final bool isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stopService');
    }
  }
}

@pragma('vm:entry-point')
bool _iosBackground(ServiceInstance service) {
  return true;
}
