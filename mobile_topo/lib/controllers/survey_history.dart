import '../models/survey.dart';

/// Manages undo/redo history for survey edits.
class SurveyHistory {
  final List<Survey> _undoStack = [];
  final List<Survey> _redoStack = [];

  static const int maxHistorySize = 50;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Records the current state before a change is made.
  /// Call this BEFORE applying the edit.
  void recordState(Survey survey) {
    _undoStack.add(survey);
    _redoStack.clear();

    // Limit history size
    if (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  /// Undoes the last change, returns the previous survey state.
  /// The caller should pass the current state to be pushed to redo stack.
  Survey? undo(Survey current) {
    if (!canUndo) return null;

    _redoStack.add(current);
    return _undoStack.removeLast();
  }

  /// Redoes the last undone change, returns the restored survey state.
  /// The caller should pass the current state to be pushed to undo stack.
  Survey? redo(Survey current) {
    if (!canRedo) return null;

    _undoStack.add(current);
    return _redoStack.removeLast();
  }

  /// Clears all history (e.g., when switching sections).
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
