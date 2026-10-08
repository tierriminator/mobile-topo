import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How many of Flutter's logical pixels fit into a millimetre on this screen,
/// used to show drawings at a true map scale.
///
/// Measured natively on Android (`android/.../DisplayPlugin.kt`) and macOS
/// (`macos/Runner/AppDelegate.swift`). iOS offers no API for the physical
/// screen size, so Apple's nominal densities are used there.
@immutable
class ScreenDensity {
  static const _channel = MethodChannel('mobile_topo/display');
  static const _mmPerInch = 25.4;

  final double logicalPixelsPerMm;

  const ScreenDensity(this.logicalPixelsPerMm);

  /// Measures the screen, falling back to a nominal density where that isn't
  /// possible
  static Future<ScreenDensity> load() async {
    try {
      final measured =
          await _channel.invokeMethod<double>('logicalPixelsPerMm');
      if (measured != null && measured > 0) return ScreenDensity(measured);
    } on MissingPluginException {
      // No native measurement on this platform
    } on PlatformException catch (e) {
      debugPrint('ScreenDensity: measuring failed: $e');
    }
    return ScreenDensity(_nominalPixelsPerInch() / _mmPerInch);
  }

  /// Logical pixels per inch when the screen can't be measured
  static double _nominalPixelsPerInch() {
    // Android's dp is defined as 1/160 inch
    if (Platform.isAndroid) return 160;
    if (Platform.isIOS) {
      // iPhones have 163 points per inch, full-size iPads 132
      final view = PlatformDispatcher.instance.implicitView;
      final shortestSide = view == null
          ? 0.0
          : (view.physicalSize / view.devicePixelRatio).shortestSide;
      return shortestSide >= 600 ? 132 : 163;
    }
    // The common desktop convention
    return 96;
  }
}
