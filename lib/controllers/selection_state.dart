import 'package:flutter/foundation.dart';
import '../models/cave.dart';

/// Holds the currently selected section and the cave containing it
/// across views.
class SelectionState extends ChangeNotifier {
  Cave? _selectedCave;
  Section? _selectedSection;

  Cave? get selectedCave => _selectedCave;
  String? get selectedCaveId => _selectedCave?.id;
  Section? get selectedSection => _selectedSection;

  void selectSection(Cave cave, Section section) {
    _selectedCave = cave;
    _selectedSection = section;
    notifyListeners();
  }

  void clearSelection() {
    _selectedCave = null;
    _selectedSection = null;
    notifyListeners();
  }

  /// Applies [change] to the selected section, if it is the one with
  /// [sectionId], and returns the changed section; returns null if another
  /// section or none is selected. The change is made to the latest state of
  /// the section, so changes made from different views all keep each other.
  Section? changeSection(
      String sectionId, Section Function(Section section) change) {
    final section = _selectedSection;
    if (section == null || section.id != sectionId) return null;
    final changed = change(section);
    _selectedSection = changed;
    _selectedCave = _selectedCave?.replaceSection(changed);
    notifyListeners();
    return changed;
  }

  /// Take over the trips of [cave] if it is the selected one
  void updateTrips(Cave cave) {
    final selected = _selectedCave;
    if (selected?.id != cave.id) return;
    _selectedCave = selected!.copyWith(trips: cave.trips);
    notifyListeners();
  }
}
