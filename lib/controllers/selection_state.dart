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

  /// Update the section data (e.g., after editing survey)
  void updateSection(Section section) {
    if (_selectedSection?.id == section.id) {
      _selectedSection = section;
      _selectedCave = _selectedCave?.replaceSection(section);
      notifyListeners();
    }
  }
}
