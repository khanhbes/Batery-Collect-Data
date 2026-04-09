import 'dart:io';

import 'package:ev_data_logger/src/models/route_point.dart';
import 'package:ev_data_logger/src/models/telemetry_sample.dart';
import 'package:ev_data_logger/src/models/trip_history_item.dart';
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
      expect(row.length, CsvService.sampleHeader.length);
      expect(row[1], 'trip_1');
      expect(row[11], 'Clouds');
    });

    test('master CSV appends exactly one row per trip summary', () async {
      final Directory dir = await Directory.systemTemp.createTemp('csv_test_');
      final CsvService service = CsvService(baseDirectory: dir);

      final TripHistoryItem trip1 = TripHistoryItem(
        tripId: 'trip_1',
        vehicleType: 'Electric Vehicle',
        startTimeUtc: DateTime.parse('2026-01-01T00:00:00Z'),
        endTimeUtc: DateTime.parse('2026-01-01T00:20:00Z'),
        durationSec: 1200,
        startSoc: 90,
        endSoc: 80,
        socDelta: 10,
        payloadKg: 100,
        sampleCount: 100,
        totalDistanceKm: 12.5,
        avgSpeedKmh: 37.5,
        maxSpeedKmh: 72.1,
        avgAccelerationMs2: 0.15,
        maxAccelerationMs2: 1.2,
        minAltitudeM: 4,
        maxAltitudeM: 25,
        startLatitude: 10.0,
        startLongitude: 106.0,
        endLatitude: 10.01,
        endLongitude: 106.02,
        ambientTempC: 31.2,
        weatherCondition: 'Clouds',
        routePreview: const <RoutePoint>[
          RoutePoint(latitude: 10.0, longitude: 106.0),
        ],
      );

      final TripHistoryItem trip2 = TripHistoryItem(
        tripId: 'trip_2',
        vehicleType: 'Electric Vehicle',
        startTimeUtc: DateTime.parse('2026-01-02T00:00:00Z'),
        endTimeUtc: DateTime.parse('2026-01-02T00:10:00Z'),
        durationSec: 600,
        startSoc: 80,
        endSoc: 74,
        socDelta: 6,
        payloadKg: 90,
        sampleCount: 60,
        totalDistanceKm: 6.0,
        avgSpeedKmh: 36.0,
        maxSpeedKmh: 65.0,
        avgAccelerationMs2: 0.1,
        maxAccelerationMs2: 1.0,
        minAltitudeM: 5,
        maxAltitudeM: 20,
        startLatitude: 10.1,
        startLongitude: 106.1,
        endLatitude: 10.2,
        endLongitude: 106.2,
        ambientTempC: null,
        weatherCondition: 'Rain',
        routePreview: const <RoutePoint>[
          RoutePoint(latitude: 10.1, longitude: 106.1),
        ],
      );

      await service.appendTripSummary(trip1);
      final File masterFile = await service.appendTripSummary(trip2);
      final List<String> masterLines = await masterFile.readAsLines();
      expect(masterLines.length, 3);
      expect(masterLines.first, CsvService.summaryHeader.join(','));
      expect(masterLines[1].startsWith('trip_1,'), true);
      expect(masterLines[2].startsWith('trip_2,'), true);
      expect(
        masterLines.where((String e) => e.startsWith('trip_1,')).length,
        1,
      );
      expect(
        masterLines.where((String e) => e.startsWith('trip_2,')).length,
        1,
      );
    });
  });
}
