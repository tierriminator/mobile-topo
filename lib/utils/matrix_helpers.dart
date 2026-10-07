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

/// Outer product `u vᵀ`: entry (i, j) is `u[i] * v[j]`.
///
/// vector_math's own `Matrix3.outer(u, v)` returns `v uᵀ` — its `setOuter`
/// writes the products in row-major order into column-major storage — so the
/// two are interchangeable only when `u` and `v` are equal.
Matrix3 outer(Vector3 u, Vector3 v) => matrix3FromRowMajor([
      u.x * v.x, u.x * v.y, u.x * v.z, //
      u.y * v.x, u.y * v.y, u.y * v.z, //
      u.z * v.x, u.z * v.y, u.z * v.z, //
    ]);

/// Average `⟨x⟩` of a non-empty list of vectors.
Vector3 mean(List<Vector3> xs) {
  assert(xs.isNotEmpty);
  var sum = Vector3.zero();
  for (final x in xs) {
    sum += x;
  }
  return sum * (1.0 / xs.length);
}

/// Covariance `Cov(x) = ⟨(x − ⟨x⟩)(x − ⟨x⟩)ᵀ⟩` of a non-empty list of vectors.
///
/// Symmetric. `vᵀ Cov(x) v` is the variance of the vectors projected onto the
/// unit direction `v`.
Matrix3 covariance(List<Vector3> xs) => crossCovariance(xs, xs);

/// Cross-covariance `Cov(y, x) = ⟨(y − ⟨y⟩)(x − ⟨x⟩)ᵀ⟩` of two equally long,
/// non-empty lists of vectors, paired by index.
///
/// Entry (i, j) is the covariance of `y[i]` with `x[j]`. Not symmetric in
/// general: `Cov(x, y)` is its transpose. The least squares fit of
/// `y ≈ A x + b` is `A = Cov(y, x) · Cov(x)⁻¹`.
///
/// The means are subtracted before multiplying rather than via
/// `⟨y xᵀ⟩ − ⟨y⟩⟨x⟩ᵀ`. The two are equal algebraically, but vector_math stores
/// float32, and subtracting two large nearly equal products there loses most
/// of the significant digits when the spread is small next to the mean.
Matrix3 crossCovariance(List<Vector3> ys, List<Vector3> xs) {
  assert(ys.length == xs.length && xs.isNotEmpty);
  final yMean = mean(ys);
  final xMean = mean(xs);
  var sum = Matrix3.zero();
  for (int i = 0; i < xs.length; i++) {
    sum += outer(ys[i] - yMean, xs[i] - xMean);
  }
  return sum.scaled(1.0 / xs.length);
}
