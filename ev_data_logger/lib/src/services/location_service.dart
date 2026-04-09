import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<void> ensurePermissions() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location service is disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        'Location permission denied. Please grant location access.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission denied forever. Please enable it in app settings.',
      );
    }
  }

  Future<Position> getCurrentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
  }

  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    );
  }

  Future<Position?> getCurrentPositionWithFallback({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      ).timeout(timeout);
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }
}
