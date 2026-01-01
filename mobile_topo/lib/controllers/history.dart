/// Manages undo/redo history for any type.
class History<T> {
  final List<T> _undoStack = [];
  final List<T> _redoStack = [];

  static const int maxSize = 50;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Records the current state before a change is made.
  /// Call this BEFORE applying the edit.
  void record(T state) {
    _undoStack.add(state);
    _redoStack.clear();

    if (_undoStack.length > maxSize) {
      _undoStack.removeAt(0);
    }
  }

  /// Undoes the last change, returns the previous state.
  T? undo(T current) {
    if (!canUndo) return null;

    _redoStack.add(current);
    return _undoStack.removeLast();
  }

  /// Redoes the last undone change, returns the restored state.
  T? redo(T current) {
    if (!canRedo) return null;

    _undoStack.add(current);
    return _redoStack.removeLast();
  }

  /// Clears all history.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
