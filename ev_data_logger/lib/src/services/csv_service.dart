import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';

import '../models/telemetry_sample.dart';

class CsvService {
  CsvService({Directory? baseDirectory}) : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;

  static const List<String> header = <String>[
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
      await file.writeAsString('${_toCsvLine(header)}\n');
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

  Future<File> finalizeTrip({
    required String tempCsvPath,
    required String tripId,
    required int startSoc,
    required int endSoc,
  }) async {
    final File tempFile = File(tempCsvPath);
    if (!await tempFile.exists()) {
      throw Exception('Temp CSV file not found: $tempCsvPath');
    }

    final Directory root = await _rootDir();
    final Directory tripsDir = Directory('${root.path}/trips');
    if (!await tripsDir.exists()) {
      await tripsDir.create(recursive: true);
    }

    final File finalFile = File('${tripsDir.path}/trip_$tripId.csv');
    final IOSink sink = finalFile.openWrite(mode: FileMode.write);
    sink.writeln(_toCsvLine(header));

    await for (final String line
        in tempFile
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty || trimmed == _toCsvLine(header)) {
        continue;
      }

      final List<String> row = trimmed.split(',');
      if (row.length < header.length) {
        continue;
      }

      row[7] = '$startSoc';
      row[8] = '$endSoc';
      sink.writeln(_toCsvLine(row));
    }

    await sink.flush();
    await sink.close();

    return finalFile;
  }

  Future<File> getMasterFile() async {
    final Directory root = await _rootDir();
    final Directory tripsDir = Directory('${root.path}/trips');
    if (!await tripsDir.exists()) {
      await tripsDir.create(recursive: true);
    }

    final File masterFile = File('${tripsDir.path}/trips_master.csv');
    if (!await masterFile.exists()) {
      await masterFile.writeAsString('${_toCsvLine(header)}\n');
    }
    return masterFile;
  }

  Future<File> appendTripToMaster(File tripCsvFile) async {
    final File master = await getMasterFile();
    final IOSink sink = master.openWrite(mode: FileMode.append);

    await for (final String line
        in tripCsvFile
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty || trimmed == _toCsvLine(header)) {
        continue;
      }
      sink.writeln(trimmed);
    }

    await sink.flush();
    await sink.close();
    return master;
  }

  String _toCsvLine(List<dynamic> row) {
    return row.map((dynamic value) => '$value').join(',');
  }
}
