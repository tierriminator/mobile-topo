import 'dart:math' as math;

/// 3D vector for calibration calculations.
class Vector3 {
  final double x, y, z;

  const Vector3(this.x, this.y, this.z);

  static const zero = Vector3(0, 0, 0);

  /// Create from list of 3 doubles.
  factory Vector3.fromList(List<double> values) {
    if (values.length != 3) {
      throw ArgumentError('Vector3 requires exactly 3 values');
    }
    return Vector3(values[0], values[1], values[2]);
  }

  // Arithmetic operations
  Vector3 operator +(Vector3 o) => Vector3(x + o.x, y + o.y, z + o.z);
  Vector3 operator -(Vector3 o) => Vector3(x - o.x, y - o.y, z - o.z);
  Vector3 operator *(double s) => Vector3(x * s, y * s, z * s);
  Vector3 operator /(double s) => Vector3(x / s, y / s, z / s);
  Vector3 operator -() => Vector3(-x, -y, -z);

  /// Dot product.
  double dot(Vector3 o) => x * o.x + y * o.y + z * o.z;

  /// Cross product.
  Vector3 cross(Vector3 o) => Vector3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  /// Vector magnitude (length).
  double get magnitude => math.sqrt(x * x + y * y + z * z);

  /// Squared magnitude (avoids sqrt).
  double get magnitudeSquared => x * x + y * y + z * z;

  /// Normalized unit vector.
  Vector3 get normalized {
    final m = magnitude;
    if (m == 0) return Vector3.zero;
    return this / m;
  }

  /// Angle between this and another vector in radians.
  double angleTo(Vector3 o) {
    final d = dot(o) / (magnitude * o.magnitude);
    // Clamp to [-1, 1] to handle floating point errors
    return math.acos(d.clamp(-1.0, 1.0));
  }

  /// Convert to list.
  List<double> toList() => [x, y, z];

  @override
  String toString() => 'Vector3($x, $y, $z)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector3 &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// 3x3 matrix (row-major) for calibration transform calculations.
class Matrix3 {
  final List<double> _m; // 9 elements [row0, row1, row2]

  Matrix3(List<double> values)
      : _m = List<double>.from(values),
        assert(values.length == 9);

  /// Create identity matrix.
  factory Matrix3.identity() => Matrix3([1, 0, 0, 0, 1, 0, 0, 0, 1]);

  /// Create zero matrix.
  factory Matrix3.zero() => Matrix3([0, 0, 0, 0, 0, 0, 0, 0, 0]);

  /// Create matrix from column vectors.
  factory Matrix3.fromColumns(Vector3 c0, Vector3 c1, Vector3 c2) => Matrix3([
        c0.x, c1.x, c2.x,
        c0.y, c1.y, c2.y,
        c0.z, c1.z, c2.z,
      ]);

  /// Create matrix from row vectors.
  factory Matrix3.fromRows(Vector3 r0, Vector3 r1, Vector3 r2) => Matrix3([
        r0.x, r0.y, r0.z,
        r1.x, r1.y, r1.z,
        r2.x, r2.y, r2.z,
      ]);

  /// Get element at (row, col).
  double get(int row, int col) => _m[row * 3 + col];

  /// Set element at (row, col).
  void set(int row, int col, double value) => _m[row * 3 + col] = value;

  /// Get row as vector.
  Vector3 row(int i) => Vector3(_m[i * 3], _m[i * 3 + 1], _m[i * 3 + 2]);

  /// Get column as vector.
  Vector3 column(int i) => Vector3(_m[i], _m[3 + i], _m[6 + i]);

  /// Matrix * Vector multiplication.
  Vector3 transform(Vector3 v) => Vector3(
        get(0, 0) * v.x + get(0, 1) * v.y + get(0, 2) * v.z,
        get(1, 0) * v.x + get(1, 1) * v.y + get(1, 2) * v.z,
        get(2, 0) * v.x + get(2, 1) * v.y + get(2, 2) * v.z,
      );

  /// Matrix * Matrix multiplication.
  Matrix3 multiply(Matrix3 o) {
    final result = Matrix3.zero();
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        double sum = 0;
        for (int k = 0; k < 3; k++) {
          sum += get(i, k) * o.get(k, j);
        }
        result.set(i, j, sum);
      }
    }
    return result;
  }

  /// Matrix + Matrix addition.
  Matrix3 operator +(Matrix3 o) {
    final result = List<double>.filled(9, 0);
    for (int i = 0; i < 9; i++) {
      result[i] = _m[i] + o._m[i];
    }
    return Matrix3(result);
  }

  /// Matrix - Matrix subtraction.
  Matrix3 operator -(Matrix3 o) {
    final result = List<double>.filled(9, 0);
    for (int i = 0; i < 9; i++) {
      result[i] = _m[i] - o._m[i];
    }
    return Matrix3(result);
  }

  /// Matrix * scalar multiplication.
  Matrix3 operator *(double s) {
    final result = List<double>.filled(9, 0);
    for (int i = 0; i < 9; i++) {
      result[i] = _m[i] * s;
    }
    return Matrix3(result);
  }

  /// Transpose.
  Matrix3 get transpose => Matrix3([
        get(0, 0), get(1, 0), get(2, 0),
        get(0, 1), get(1, 1), get(2, 1),
        get(0, 2), get(1, 2), get(2, 2),
      ]);

  /// Determinant.
  double get determinant =>
      get(0, 0) * (get(1, 1) * get(2, 2) - get(1, 2) * get(2, 1)) -
      get(0, 1) * (get(1, 0) * get(2, 2) - get(1, 2) * get(2, 0)) +
      get(0, 2) * (get(1, 0) * get(2, 1) - get(1, 1) * get(2, 0));

  /// Inverse using cofactor method.
  Matrix3 get inverse {
    final det = determinant;
    if (det.abs() < 1e-10) {
      throw StateError('Matrix is not invertible (determinant is zero)');
    }

    // Cofactor matrix
    final c00 = get(1, 1) * get(2, 2) - get(1, 2) * get(2, 1);
    final c01 = -(get(1, 0) * get(2, 2) - get(1, 2) * get(2, 0));
    final c02 = get(1, 0) * get(2, 1) - get(1, 1) * get(2, 0);

    final c10 = -(get(0, 1) * get(2, 2) - get(0, 2) * get(2, 1));
    final c11 = get(0, 0) * get(2, 2) - get(0, 2) * get(2, 0);
    final c12 = -(get(0, 0) * get(2, 1) - get(0, 1) * get(2, 0));

    final c20 = get(0, 1) * get(1, 2) - get(0, 2) * get(1, 1);
    final c21 = -(get(0, 0) * get(1, 2) - get(0, 2) * get(1, 0));
    final c22 = get(0, 0) * get(1, 1) - get(0, 1) * get(1, 0);

    // Adjugate (transpose of cofactor matrix) divided by determinant
    return Matrix3([
      c00 / det, c10 / det, c20 / det,
      c01 / det, c11 / det, c21 / det,
      c02 / det, c12 / det, c22 / det,
    ]);
  }

  /// Create a copy of this matrix.
  Matrix3 copy() => Matrix3(List<double>.from(_m));

  /// Internal elements (for serialization).
  List<double> get elements => List<double>.from(_m);

  @override
  String toString() =>
      'Matrix3(\n'
      '  [${get(0, 0)}, ${get(0, 1)}, ${get(0, 2)}],\n'
      '  [${get(1, 0)}, ${get(1, 1)}, ${get(1, 2)}],\n'
      '  [${get(2, 0)}, ${get(2, 1)}, ${get(2, 2)}]\n'
      ')';
}

/// Solve linear system Ax = b using Gaussian elimination with partial pivoting.
/// Returns solution vector x, or null if system is singular.
Vector3? solveLinearSystem3(Matrix3 a, Vector3 b) {
  // Augmented matrix [A|b]
  final aug = List<List<double>>.generate(
    3,
    (i) => [a.get(i, 0), a.get(i, 1), a.get(i, 2), b.toList()[i]],
  );

  // Forward elimination with partial pivoting
  for (int col = 0; col < 3; col++) {
    // Find pivot
    int maxRow = col;
    for (int row = col + 1; row < 3; row++) {
      if (aug[row][col].abs() > aug[maxRow][col].abs()) {
        maxRow = row;
      }
    }

    // Swap rows
    if (maxRow != col) {
      final temp = aug[col];
      aug[col] = aug[maxRow];
      aug[maxRow] = temp;
    }

    // Check for singular matrix
    if (aug[col][col].abs() < 1e-10) {
      return null;
    }

    // Eliminate column
    for (int row = col + 1; row < 3; row++) {
      final factor = aug[row][col] / aug[col][col];
      for (int j = col; j < 4; j++) {
        aug[row][j] -= factor * aug[col][j];
      }
    }
  }

  // Back substitution
  final x = List<double>.filled(3, 0);
  for (int i = 2; i >= 0; i--) {
    x[i] = aug[i][3];
    for (int j = i + 1; j < 3; j++) {
      x[i] -= aug[i][j] * x[j];
    }
    x[i] /= aug[i][i];
  }

  return Vector3.fromList(x);
}
