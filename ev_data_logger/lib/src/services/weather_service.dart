import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_secrets.dart';
import '../models/weather_snapshot.dart';

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 6);

  Future<WeatherSnapshot?> fetchCurrent(double lat, double lon) async {
    const String apiKey = openWeatherApiKey;
    if (apiKey.isEmpty) {
      return null;
    }

    final Uri uri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
      'lat': '$lat',
      'lon': '$lon',
      'appid': apiKey,
      'units': 'metric',
    });

    try {
      final http.Response response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        return null;
      }
      return parseSnapshot(response.body);
    } catch (_) {
      return null;
    }
  }

  WeatherSnapshot? parseSnapshot(String body) {
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final dynamic weatherList = decoded['weather'];
    final dynamic mainObject = decoded['main'];
    if (weatherList is! List || weatherList.isEmpty || mainObject is! Map) {
      return null;
    }

    final dynamic firstWeather = weatherList.first;
    if (firstWeather is! Map) {
      return null;
    }

    final String? condition = firstWeather['main'] as String?;
    final double? temp = (mainObject['temp'] as num?)?.toDouble();

    if (condition == null || condition.isEmpty) {
      return null;
    }

    return WeatherSnapshot(condition: condition, ambientTempC: temp);
  }
}
