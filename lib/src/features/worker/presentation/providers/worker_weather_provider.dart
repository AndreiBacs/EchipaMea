import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/worker_weather_api.dart';

class WorkerWeatherCoords {
  const WorkerWeatherCoords({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkerWeatherCoords &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

final workerWeatherApiProvider = Provider<WorkerWeatherApi>((ref) {
  return WorkerWeatherApi();
});

final workerWeatherProvider =
    FutureProvider.family<WorkerWeatherSnapshot, WorkerWeatherCoords>((
      ref,
      coords,
    ) async {
      return ref
          .read(workerWeatherApiProvider)
          .fetchCurrent(latitude: coords.latitude, longitude: coords.longitude);
    });
