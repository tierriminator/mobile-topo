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

  /// A pending request to show the reference points table of the data view,
  /// with the reference point to select, if any
  ({Point? station})? _referencePoints;

  /// The view a pending request is for, if any
  NavigationTarget? get pendingTarget =>
      _pending?.target ??
      (_referencePoints == null ? null : NavigationTarget.data);

  /// Asks to show [station] in [target]
  void show(Point station, NavigationTarget target) {
    _pending = (station: station, target: target);
    _referencePoints = null;
    notifyListeners();
  }

  /// Asks to show the reference points in the data view, selecting the one
  /// of [station] if given
  void showReferencePoints([Point? station]) {
    _referencePoints = (station: station);
    _pending = null;
    notifyListeners();
  }

  /// Takes a pending request to show the reference points, so it is handled
  /// only once
  ({Point? station})? takeReferencePoints() {
    final pending = _referencePoints;
    _referencePoints = null;
    return pending;
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
