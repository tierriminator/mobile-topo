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

  /// Take over the removal of the cave with [caveId]: clears the selection
  /// if it is in that cave
  void removeCave(String caveId) {
    if (_selectedCave?.id == caveId) clearSelection();
  }

  /// Take over the removal of a section from the cave with [caveId]: clears
  /// the selection if it is the selected section, or removes it from the
  /// selected cave otherwise
  void removeSection(String caveId, String sectionId) {
    final selected = _selectedCave;
    if (selected?.id != caveId) return;
    if (_selectedSection?.id == sectionId) {
      clearSelection();
      return;
    }
    _selectedCave = selected!.removeSection(sectionId);
    notifyListeners();
  }

  /// Take over the trips of [cave] if it is the selected one
  void updateTrips(Cave cave) {
    final selected = _selectedCave;
    if (selected?.id != cave.id) return;
    _selectedCave = selected!.copyWith(trips: cave.trips);
    notifyListeners();
  }

  /// Take over the coordinate system of [cave] if it is the selected one
  void updateCoordinateSystem(Cave cave) {
    final selected = _selectedCave;
    if (selected?.id != cave.id) return;
    _selectedCave =
        selected!.copyWith(coordinateSystem: cave.coordinateSystem);
    notifyListeners();
  }}
