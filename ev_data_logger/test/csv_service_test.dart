import 'dart:io';

import 'package:ev_data_logger/src/models/telemetry_sample.dart';
import 'package:ev_data_logger/src/services/csv_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvService', () {
    test('serialize uses fixed schema order and UTC timestamp', () {
      final sample = TelemetrySample(
        timestampUtc: DateTime.parse('2026-01-01T00:00:00Z'),
        tripId: 'trip_1',
        latitude: 10.0,
        longitude: 106.0,
        speedKmh: 36,
        altitudeM: 5,
        accelerationMs2: 0.2,
        startSoc: 80,
        endSoc: null,
        payloadKg: 120,
        ambientTempC: null,
        weatherCondition: 'Clouds',
      );

      final row = CsvService().serializeSample(sample);
      expect(row[0], '2026-01-01T00:00:00.000Z');
      expect(row.length, CsvService.header.length);
      expect(row[1], 'trip_1');
      expect(row[11], 'Clouds');
    });

    test('finalize fills end_soc for all rows', () async {
      final Directory dir = await Directory.systemTemp.createTemp('csv_test_');
      final CsvService service = CsvService(baseDirectory: dir);

      final file = await service.createTempFile('tripx');

      final sample1 = TelemetrySample(
        timestampUtc: DateTime.parse('2026-01-01T00:00:00Z'),
        tripId: 'tripx',
        latitude: 1,
        longitude: 1,
        speedKmh: 10,
        altitudeM: 2,
        accelerationMs2: 0,
        startSoc: 90,
        endSoc: null,
        payloadKg: 0,
        ambientTempC: null,
        weatherCondition: 'unknown',
      );

      final sample2 = TelemetrySample(
        timestampUtc: DateTime.parse('2026-01-01T00:00:01Z'),
        tripId: 'tripx',
        latitude: 1,
        longitude: 1,
        speedKmh: 20,
        altitudeM: 2,
        accelerationMs2: 1,
        startSoc: 90,
        endSoc: null,
        payloadKg: 0,
        ambientTempC: null,
        weatherCondition: 'unknown',
      );

      await service.appendSample(sample1, file.path);
      await service.appendSample(sample2, file.path);

      final File finalFile = await service.finalizeTrip(
        tempCsvPath: file.path,
        tripId: 'tripx',
        startSoc: 90,
        endSoc: 70,
      );

      final List<String> lines = await finalFile.readAsLines();
      expect(lines.length, 3);
      expect(lines[1].contains(',90,70,'), true);
      expect(lines[2].contains(',90,70,'), true);

      final File masterFile = await service.appendTripToMaster(finalFile);
      final List<String> masterLines = await masterFile.readAsLines();
      expect(masterLines.length, 3);
      expect(masterLines.first, CsvService.header.join(','));
      expect(masterLines[1].contains(',90,70,'), true);
      expect(masterLines[2].contains(',90,70,'), true);
    });
  });
}
