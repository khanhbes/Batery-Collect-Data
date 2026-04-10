import 'dart:io';

import '../models/charging_session_item.dart';
import '../models/trip_history_item.dart';
import '../models/telemetry_sample.dart';

class CsvService {
  CsvService({required Directory baseDirectory}) : _baseDirectory = baseDirectory;

  final Directory _baseDirectory;

  static const List<String> sampleHeader = <String>[
    'timestamp',
    'trip_id',
    'latitude',
    'longitude',
    'speed_kmh',
    'altitude_m',
    'acceleration_ms2',
    'start_soc',
    'end_soc',
    'payload_kg',
    'ambient_temp_c',
    'weather_condition',
  ];

  static const List<String> summaryHeader = TripHistoryItem.masterHeader;

  Future<Directory> _rootDir() async {
    return _baseDirectory;
  }

  Future<File> createTempFile(String tripId) async {
    final Directory root = await _rootDir();
    final Directory tripsDir = Directory('${root.path}/trips');
    if (!await tripsDir.exists()) {
      await tripsDir.create(recursive: true);
    }

    final File file = File('${tripsDir.path}/temp_trip_$tripId.csv');
    if (!await file.exists()) {
      await file.writeAsString('${_toCsvLine(sampleHeader)}\n');
    }
    return file;
  }

  Future<void> appendSample(TelemetrySample sample, String csvPath) async {
    final File file = File(csvPath);
    if (!await file.exists()) {
      throw Exception('CSV file not found: $csvPath');
    }

    final List<dynamic> row = serializeSample(sample);
    await file.writeAsString('${_toCsvLine(row)}\n', mode: FileMode.append);
  }

  List<dynamic> serializeSample(TelemetrySample sample) {
    return <dynamic>[
      sample.timestampUtc.toUtc().toIso8601String(),
      sample.tripId,
      sample.latitude,
      sample.longitude,
      sample.speedKmh,
      sample.altitudeM,
      sample.accelerationMs2,
      sample.startSoc,
      sample.endSoc ?? '',
      sample.payloadKg,
      sample.ambientTempC ?? '',
      sample.weatherCondition,
    ];
  }

  Future<File> getMasterFile() async {
    final Directory root = await _rootDir();
    final Directory tripsDir = Directory('${root.path}/trips');
    if (!await tripsDir.exists()) {
      await tripsDir.create(recursive: true);
    }

    final File masterFile = File('${tripsDir.path}/trips_master.csv');
    if (!await masterFile.exists()) {
      await masterFile.writeAsString('${_toCsvLine(summaryHeader)}\n');
    }
    return masterFile;
  }

  Future<File> appendTripSummary(TripHistoryItem summary) async {
    final File master = await getMasterFile();
    await master.writeAsString(
      '${_toCsvLine(summary.toMasterCsvRow())}\n',
      mode: FileMode.append,
    );
    return master;
  }

  Future<File> getChargingLogFile() async {
    final Directory root = await _rootDir();
    final Directory tripsDir = Directory('${root.path}/trips');
    if (!await tripsDir.exists()) {
      await tripsDir.create(recursive: true);
    }

    final File file = File('${tripsDir.path}/Charging_log.csv');
    if (!await file.exists()) {
      await file.writeAsString(
        '${_toCsvLine(ChargingSessionItem.csvHeader)}\n',
      );
    }
    return file;
  }

  Future<File> appendChargingSummary(ChargingSessionItem item) async {
    final File file = await getChargingLogFile();
    await file.writeAsString(
      '${_toCsvLine(item.toCsvRow())}\n',
      mode: FileMode.append,
    );
    return file;
  }

  Future<void> deleteTempFile(String tempCsvPath) async {
    final File file = File(tempCsvPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteRawFile(String rawDataPath) async {
    final File file = File(rawDataPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Move a temp trip CSV to a permanent raw path.
  /// Returns the new path, or null if the temp file did not exist.
  Future<String?> moveToRawPath(String tempCsvPath, String tripId) async {
    final File tempFile = File(tempCsvPath);
    if (!await tempFile.exists()) {
      return null;
    }

    final Directory root = await _rootDir();
    final Directory rawDir = Directory('${root.path}/trips/raw');
    if (!await rawDir.exists()) {
      await rawDir.create(recursive: true);
    }

    final String newPath = '${rawDir.path}/trip_$tripId.csv';
    final File newFile = await tempFile.rename(newPath);
    return newFile.path;
  }

  String _toCsvLine(List<dynamic> row) {
    return row.map((dynamic value) => '$value').join(',');
  }
}
