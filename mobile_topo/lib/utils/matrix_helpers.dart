import 'package:vector_math/vector_math.dart';

/// Extension to bridge API differences from the previous custom implementation.
extension Matrix3Helpers on Matrix3 {
  /// Get element at (row, col) - alias for entry().
  double get(int row, int col) => entry(row, col);

  /// Set element at (row, col) - alias for setEntry().
  void set(int row, int col, double value) => setEntry(row, col, value);

  /// Transform vector and return a new vector.
  ///
  /// Deliberately *not* named `transform`: `Matrix3.transform` is an instance
  /// method of vector_math that transforms its argument **in place**. An
  /// extension member can never shadow an instance member, so a `transform`
  /// alias here would silently resolve to the mutating version and corrupt
  /// the caller's vector.
  Vector3 transformVector(Vector3 v) => transformed(v);

  /// Get inverse as new matrix.
  Matrix3 get inverse => Matrix3.copy(this)..invert();

  /// Return a copy with one element changed.
  Matrix3 withElement(int row, int col, double value) {
    final result = Matrix3.copy(this);
    result.setEntry(row, col, value);
    return result;
  }

  /// Get elements as row-major list.
  List<double> get elements {
    final result = <double>[];
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        result.add(entry(r, c));
      }
    }
    return result;
  }
}

/// Create Matrix3 from row-major list of 9 doubles.
Matrix3 matrix3FromRowMajor(List<double> values) {
  assert(values.length == 9);
  final m = Matrix3.zero();
  for (int r = 0; r < 3; r++) {
    for (int c = 0; c < 3; c++) {
      m.setEntry(r, c, values[r * 3 + c]);
    }
  }
  return m;
}

/// Extension for Vector3 to add magnitude alias.
extension Vector3Helpers on Vector3 {
  /// Alias for length (magnitude of vector).
  double get magnitude => length;

  /// Alias for length2 (squared magnitude).
  double get magnitudeSquared => length2;
}
