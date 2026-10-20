import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// One position fix of the device
class LocationFix {
  /// WGS84 degrees
  final double latitude;
  final double longitude;

  /// Metres above mean sea level, if reported
  final double? altitude;

  /// Estimated horizontal accuracy in metres
  final double accuracy;

  /// Estimated vertical accuracy in metres, if reported
  final double? altitudeAccuracy;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.accuracy,
    this.altitudeAccuracy,
  });
}

/// Why positions cannot be measured
enum LocationProblem {
  /// Location services are turned off on the device
  disabled,

  /// The app may not use the location
  denied,

  /// The app may only use an approximate location, which is too coarse
  imprecise,
}

/// Access to the device's position, for measuring reference points
abstract class LocationService {
  /// Gets ready to measure, asking for permission if needed. Returns why it
  /// cannot measure, or null if it can.
  Future<LocationProblem?> prepare();

  /// Fixes as the device determines them, at the best accuracy it offers
  Stream<LocationFix> fixes();

  /// Opens the system settings where [problem] can be solved
  Future<void> openSettings(LocationProblem problem);
}

/// [LocationService] of the platform, through the geolocator plugin
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationProblem?> prepare() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationProblem.disabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      return LocationProblem.denied;
    }
    if (await Geolocator.getLocationAccuracy() ==
        LocationAccuracyStatus.reduced) {
      return LocationProblem.imprecise;
    }
    return null;
  }

  @override
  Stream<LocationFix> fixes() => Geolocator.getPositionStream(
        locationSettings: _settings,
      ).map((p) => LocationFix(
            latitude: p.latitude,
            longitude: p.longitude,
            altitude: p.hasAltitude ? p.altitude : null,
            accuracy: p.accuracy,
            altitudeAccuracy: p.hasAltitudeAccuracy && p.altitudeAccuracy > 0
                ? p.altitudeAccuracy
                : null,
          ));

  @override
  Future<void> openSettings(LocationProblem problem) async {
    if (problem == LocationProblem.disabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  /// Every fix at the highest accuracy, without filtering by distance
  static LocationSettings get _settings => switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 1),
            // The satellite receiver itself rather than the fused provider,
            // which mixes in network positions
            forceLocationManager: true,
            // Android reports altitudes above the ellipsoid, some 50 m off
            // the sea level altitudes caves are mapped in
            useMSLAltitude: true,
          ),
        TargetPlatform.iOS || TargetPlatform.macOS => AppleSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            pauseLocationUpdatesAutomatically: false,
          ),
        _ => const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
          ),
      };
}
