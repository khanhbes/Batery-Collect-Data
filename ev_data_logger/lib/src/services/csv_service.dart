import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/trip_history_item.dart';
import '../models/telemetry_sample.dart';

class CsvService {
  CsvService({Directory? baseDirectory}) : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;

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
    if (_baseDirectory != null) {
      return _baseDirectory;
    }
    return getApplicationDocumentsDirectory();
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

  Future<void> deleteTempFile(String tempCsvPath) async {
    final File file = File(tempCsvPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _toCsvLine(List<dynamic> row) {
    return row.map((dynamic value) => '$value').join(',');
  }
}
