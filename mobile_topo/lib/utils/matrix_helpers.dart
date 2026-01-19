import 'package:vector_math/vector_math.dart';

/// Extension to bridge API differences from the previous custom implementation.
extension Matrix3Helpers on Matrix3 {
  /// Get element at (row, col) - alias for entry().
  double get(int row, int col) => entry(row, col);

  /// Set element at (row, col) - alias for setEntry().
  void set(int row, int col, double value) => setEntry(row, col, value);

  /// Transform vector and return new vector (doesn't modify input).
  Vector3 transform(Vector3 v) => transformed(v);

  /// Matrix multiplication.
  Matrix3 multiply(Matrix3 other) => this * other;

  /// Get inverse as new matrix.
  Matrix3 get inverse => Matrix3.copy(this)..invert();

  /// Get transpose as new matrix.
  Matrix3 get transposed => Matrix3.copy(this)..transpose();

  /// Multiply this matrix by transpose of other: this * other^T.
  Matrix3 multiplyTransposed(Matrix3 other) {
    final oT = Matrix3.copy(other)..transpose();
    return this * oT;
  }

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
