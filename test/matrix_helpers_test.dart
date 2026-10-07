import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/utils/matrix_helpers.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('outer', () {
    test('is u vᵀ: entry (i, j) is u[i] * v[j]', () {
      final m = outer(Vector3(1, 2, 3), Vector3(1, 0, 0));

      expect(m.entry(1, 0), 2.0);
      expect(m.entry(2, 0), 3.0);
      expect(m.entry(0, 1), 0.0);
    });

    test('is the transpose of vector_math Matrix3.outer for unequal vectors',
        () {
      final u = Vector3(1, 2, 3);
      final v = Vector3(4, 5, 6);
      final ours = outer(u, v);
      final theirs = Matrix3.outer(u, v);

      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          expect(ours.entry(i, j), theirs.entry(j, i));
        }
      }
      expect(ours.entry(0, 1), isNot(theirs.entry(0, 1)));
    });
  });

  group('mean', () {
    test('averages component-wise', () {
      final m = mean([Vector3(1, 0, 4), Vector3(3, 2, 0)]);

      expect(m.x, 2.0);
      expect(m.y, 1.0);
      expect(m.z, 2.0);
    });
  });

  group('covariance', () {
    test('holds the per-axis variances on the diagonal', () {
      // Wide along x, narrow along y, flat along z.
      final c = covariance([
        Vector3(2, 0, 0),
        Vector3(-2, 0, 0),
        Vector3(0, 1, 0),
        Vector3(0, -1, 0),
      ]);

      expect(c.entry(0, 0), closeTo(2.0, 1e-6));
      expect(c.entry(1, 1), closeTo(0.5, 1e-6));
      expect(c.entry(2, 2), closeTo(0.0, 1e-6));
      expect(c.entry(0, 1), closeTo(0.0, 1e-6));
    });

    test('measures spread around the centroid, not the origin', () {
      final offset = Vector3(10, -7, 3);
      final centred = [Vector3(1, 0, 0), Vector3(-1, 0, 0)];
      final shifted = [for (final v in centred) v + offset];

      expect(covariance(shifted).entry(0, 0),
          closeTo(covariance(centred).entry(0, 0), 1e-5));
    });

    test('vᵀ Cov v is the variance along v, so a tilted line is singular', () {
      // All points on the diagonal x = y: large variance on both axes, yet
      // none across the line.
      final c = covariance([
        Vector3(1, 1, 0),
        Vector3(-1, -1, 0),
        Vector3(2, 2, 0),
        Vector3(-2, -2, 0),
      ]);

      final along = Vector3(1, 1, 0).normalized();
      final across = Vector3(1, -1, 0).normalized();
      expect(along.dot(c.transformVector(along)), closeTo(5.0, 1e-5));
      expect(across.dot(c.transformVector(across)), closeTo(0.0, 1e-5));
    });

    test('keeps its precision when the spread is small next to the mean', () {
      // vector_math stores float32: ⟨x²⟩ − ⟨x⟩² here would subtract two
      // numbers around 1e8 that differ by 1, below float32 resolution.
      final c = covariance([Vector3(10001, 0, 0), Vector3(9999, 0, 0)]);

      expect(c.entry(0, 0), closeTo(1.0, 1e-3));
    });
  });

  group('crossCovariance', () {
    test('swapping its arguments transposes it', () {
      final xs = [Vector3(1, 0, 2), Vector3(0, 3, 1), Vector3(-1, 1, 0)];
      final ys = [Vector3(2, 1, 0), Vector3(1, -1, 4), Vector3(0, 2, 2)];
      final yx = crossCovariance(ys, xs);
      final xy = crossCovariance(xs, ys);

      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          expect(yx.entry(i, j), closeTo(xy.entry(j, i), 1e-6));
        }
      }
    });

    test('Cov(y, x) · Cov(x)⁻¹ recovers the matrix of an affine map', () {
      // The least squares solution eq. 6 relies on: for y = A x + b exactly,
      // the regression returns A.
      final a = matrix3FromRowMajor([
        1.2, -0.3, 0.1, //
        0.4, 0.9, -0.2, //
        -0.1, 0.25, 1.1, //
      ]);
      final b = Vector3(0.5, -1.0, 2.0);
      final rng = math.Random(1);
      final xs = [
        for (int i = 0; i < 40; i++)
          Vector3(rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1,
              rng.nextDouble() * 2 - 1),
      ];
      final ys = [for (final x in xs) a.transformVector(x) + b];

      final fitted = crossCovariance(ys, xs).multiplied(covariance(xs).inverse);

      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          expect(fitted.entry(i, j), closeTo(a.entry(i, j), 1e-4),
              reason: 'A[$i,$j]');
        }
      }
    });
  });
}
