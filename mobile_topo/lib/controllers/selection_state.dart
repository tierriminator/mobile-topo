import 'package:flutter/foundation.dart';
import '../models/cave.dart';

/// Holds the currently selected section across views.
class SelectionState extends ChangeNotifier {
  String? _selectedCaveId;
  Section? _selectedSection;

  String? get selectedCaveId => _selectedCaveId;
  Section? get selectedSection => _selectedSection;

  void selectSection(String caveId, Section section) {
    _selectedCaveId = caveId;
    _selectedSection = section;
    notifyListeners();
  }

  void clearSelection() {
    _selectedCaveId = null;
    _selectedSection = null;
    notifyListeners();
  }

  /// Update the section data (e.g., after editing survey)
  void updateSection(Section section) {
    if (_selectedSection?.id == section.id) {
      _selectedSection = section;
      notifyListeners();
    }
  }
}
