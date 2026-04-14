import 'dart:convert';

import 'package:http/http.dart' as http;

class WorkerWeatherSnapshot {
  const WorkerWeatherSnapshot({
    required this.temperatureC,
    required this.weatherCode,
    required this.windSpeedKmh,
  });

  final double temperatureC;
  final int weatherCode;
  final double windSpeedKmh;
}

class WorkerWeatherApi {
  Future<WorkerWeatherSnapshot> fetchCurrent({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'temperature_2m,weather_code,wind_speed_10m',
      'timezone': 'auto',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Weather API failed with status ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw Exception('Weather API returned invalid payload');
    }
    final current = json['current'];
    if (current is! Map<String, dynamic>) {
      throw Exception('Weather API payload missing current weather');
    }

    final temperature = (current['temperature_2m'] as num?)?.toDouble();
    final weatherCode = (current['weather_code'] as num?)?.toInt();
    final wind = (current['wind_speed_10m'] as num?)?.toDouble();
    if (temperature == null || weatherCode == null || wind == null) {
      throw Exception('Weather API payload missing weather fields');
    }

    return WorkerWeatherSnapshot(
      temperatureC: temperature,
      weatherCode: weatherCode,
      windSpeedKmh: wind,
    );
  }
}
