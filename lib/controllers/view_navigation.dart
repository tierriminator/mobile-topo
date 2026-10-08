import 'package:flutter/foundation.dart';

import '../models/survey.dart';

/// Views a station can be shown in from another view
enum NavigationTarget { data, map, outline, sideView }

/// Requests to show a station in another view, like PocketTopo's "-> Map"
/// menu commands. The main screen switches to the target's tab, and the
/// target view takes the request to select the station and bring it into
/// view.
class ViewNavigation extends ChangeNotifier {
  ({Point station, NavigationTarget target})? _pending;

  /// The view a pending request is for, if any
  NavigationTarget? get pendingTarget => _pending?.target;

  /// Asks to show [station] in [target]
  void show(Point station, NavigationTarget target) {
    _pending = (station: station, target: target);
    notifyListeners();
  }

  /// Takes the pending request if it is for one of [targets], so it is
  /// handled only once
  ({Point station, NavigationTarget target})? take(
      Set<NavigationTarget> targets) {
    final pending = _pending;
    if (pending == null || !targets.contains(pending.target)) return null;
    _pending = null;
    return pending;
  }
}
