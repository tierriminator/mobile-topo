import '../models/sketch.dart';

/// Manages undo/redo history for sketch edits.
class SketchHistory {
  final List<Sketch> _undoStack = [];
  final List<Sketch> _redoStack = [];

  static const int maxHistorySize = 50;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Records the current state before a change is made.
  /// Call this BEFORE applying the edit.
  void recordState(Sketch sketch) {
    _undoStack.add(sketch);
    _redoStack.clear();

    // Limit history size
    if (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  /// Undoes the last change, returns the previous sketch state.
  /// The caller should pass the current state to be pushed to redo stack.
  Sketch? undo(Sketch current) {
    if (!canUndo) return null;

    _redoStack.add(current);
    return _undoStack.removeLast();
  }

  /// Redoes the last undone change, returns the restored sketch state.
  /// The caller should pass the current state to be pushed to undo stack.
  Sketch? redo(Sketch current) {
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
