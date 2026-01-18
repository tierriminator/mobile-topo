import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/utils/linear_algebra.dart';

void main() {
  group('Vector3', () {
    group('construction', () {
      test('creates vector with given values', () {
        const v = Vector3(1, 2, 3);
        expect(v.x, 1);
        expect(v.y, 2);
        expect(v.z, 3);
      });

      test('zero constant is all zeros', () {
        expect(Vector3.zero.x, 0);
        expect(Vector3.zero.y, 0);
        expect(Vector3.zero.z, 0);
      });

      test('fromList creates vector from list', () {
        final v = Vector3.fromList([4, 5, 6]);
        expect(v.x, 4);
        expect(v.y, 5);
        expect(v.z, 6);
      });

      test('fromList throws for wrong length', () {
        expect(() => Vector3.fromList([1, 2]), throwsArgumentError);
        expect(() => Vector3.fromList([1, 2, 3, 4]), throwsArgumentError);
      });
    });

    group('arithmetic', () {
      test('addition', () {
        const a = Vector3(1, 2, 3);
        const b = Vector3(4, 5, 6);
        final c = a + b;
        expect(c.x, 5);
        expect(c.y, 7);
        expect(c.z, 9);
      });

      test('subtraction', () {
        const a = Vector3(5, 7, 9);
        const b = Vector3(1, 2, 3);
        final c = a - b;
        expect(c.x, 4);
        expect(c.y, 5);
        expect(c.z, 6);
      });

      test('scalar multiplication', () {
        const v = Vector3(1, 2, 3);
        final scaled = v * 2;
        expect(scaled.x, 2);
        expect(scaled.y, 4);
        expect(scaled.z, 6);
      });

      test('scalar division', () {
        const v = Vector3(2, 4, 6);
        final divided = v / 2;
        expect(divided.x, 1);
        expect(divided.y, 2);
        expect(divided.z, 3);
      });

      test('negation', () {
        const v = Vector3(1, -2, 3);
        final neg = -v;
        expect(neg.x, -1);
        expect(neg.y, 2);
        expect(neg.z, -3);
      });
    });

    group('operations', () {
      test('dot product of orthogonal vectors is zero', () {
        const a = Vector3(1, 0, 0);
        const b = Vector3(0, 1, 0);
        expect(a.dot(b), 0);
      });

      test('dot product of parallel vectors', () {
        const a = Vector3(1, 0, 0);
        const b = Vector3(3, 0, 0);
        expect(a.dot(b), 3);
      });

      test('dot product general case', () {
        const a = Vector3(1, 2, 3);
        const b = Vector3(4, 5, 6);
        // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
        expect(a.dot(b), 32);
      });

      test('cross product of parallel vectors is zero', () {
        const a = Vector3(1, 0, 0);
        const b = Vector3(2, 0, 0);
        final c = a.cross(b);
        expect(c.x, 0);
        expect(c.y, 0);
        expect(c.z, 0);
      });

      test('cross product i x j = k', () {
        const i = Vector3(1, 0, 0);
        const j = Vector3(0, 1, 0);
        final k = i.cross(j);
        expect(k.x, 0);
        expect(k.y, 0);
        expect(k.z, 1);
      });

      test('cross product j x k = i', () {
        const j = Vector3(0, 1, 0);
        const k = Vector3(0, 0, 1);
        final i = j.cross(k);
        expect(i.x, 1);
        expect(i.y, 0);
        expect(i.z, 0);
      });

      test('cross product k x i = j', () {
        const k = Vector3(0, 0, 1);
        const i = Vector3(1, 0, 0);
        final j = k.cross(i);
        expect(j.x, 0);
        expect(j.y, 1);
        expect(j.z, 0);
      });

      test('magnitude of unit vectors is 1', () {
        expect(const Vector3(1, 0, 0).magnitude, 1);
        expect(const Vector3(0, 1, 0).magnitude, 1);
        expect(const Vector3(0, 0, 1).magnitude, 1);
      });

      test('magnitude general case', () {
        const v = Vector3(3, 4, 0);
        expect(v.magnitude, 5); // 3-4-5 triangle
      });

      test('magnitudeSquared avoids sqrt', () {
        const v = Vector3(1, 2, 3);
        expect(v.magnitudeSquared, 14); // 1 + 4 + 9
      });

      test('normalized returns unit vector', () {
        const v = Vector3(3, 4, 0);
        final n = v.normalized;
        expect(n.magnitude, closeTo(1.0, 1e-10));
        expect(n.x, closeTo(0.6, 1e-10));
        expect(n.y, closeTo(0.8, 1e-10));
        expect(n.z, closeTo(0.0, 1e-10));
      });

      test('normalized of zero vector returns zero', () {
        final n = Vector3.zero.normalized;
        expect(n.x, 0);
        expect(n.y, 0);
        expect(n.z, 0);
      });

      test('angleTo returns correct angle', () {
        const a = Vector3(1, 0, 0);
        const b = Vector3(0, 1, 0);
        expect(a.angleTo(b), closeTo(math.pi / 2, 1e-10));
      });

      test('angleTo parallel vectors is 0', () {
        const a = Vector3(1, 0, 0);
        const b = Vector3(2, 0, 0);
        expect(a.angleTo(b), closeTo(0, 1e-10));
      });

      test('angleTo antiparallel vectors is pi', () {
        const a = Vector3(1, 0, 0);
        const b = Vector3(-1, 0, 0);
        expect(a.angleTo(b), closeTo(math.pi, 1e-10));
      });
    });

    group('conversion', () {
      test('toList returns correct list', () {
        const v = Vector3(1, 2, 3);
        expect(v.toList(), [1, 2, 3]);
      });
    });

    group('equality', () {
      test('equal vectors are equal', () {
        const a = Vector3(1, 2, 3);
        const b = Vector3(1, 2, 3);
        expect(a == b, true);
        expect(a.hashCode, b.hashCode);
      });

      test('different vectors are not equal', () {
        const a = Vector3(1, 2, 3);
        const b = Vector3(1, 2, 4);
        expect(a == b, false);
      });
    });
  });

  group('Matrix3', () {
    group('construction', () {
      test('creates matrix with given values', () {
        final m = Matrix3([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        expect(m.get(0, 0), 1);
        expect(m.get(0, 1), 2);
        expect(m.get(0, 2), 3);
        expect(m.get(1, 0), 4);
        expect(m.get(1, 1), 5);
        expect(m.get(1, 2), 6);
        expect(m.get(2, 0), 7);
        expect(m.get(2, 1), 8);
        expect(m.get(2, 2), 9);
      });

      test('identity matrix', () {
        final m = Matrix3.identity();
        expect(m.get(0, 0), 1);
        expect(m.get(0, 1), 0);
        expect(m.get(0, 2), 0);
        expect(m.get(1, 0), 0);
        expect(m.get(1, 1), 1);
        expect(m.get(1, 2), 0);
        expect(m.get(2, 0), 0);
        expect(m.get(2, 1), 0);
        expect(m.get(2, 2), 1);
      });

      test('zero matrix', () {
        final m = Matrix3.zero();
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            expect(m.get(i, j), 0);
          }
        }
      });

      test('fromColumns creates from column vectors', () {
        const c0 = Vector3(1, 4, 7);
        const c1 = Vector3(2, 5, 8);
        const c2 = Vector3(3, 6, 9);
        final m = Matrix3.fromColumns(c0, c1, c2);
        expect(m.column(0).x, 1);
        expect(m.column(0).y, 4);
        expect(m.column(0).z, 7);
        expect(m.column(1).x, 2);
        expect(m.column(2).x, 3);
      });

      test('fromRows creates from row vectors', () {
        const r0 = Vector3(1, 2, 3);
        const r1 = Vector3(4, 5, 6);
        const r2 = Vector3(7, 8, 9);
        final m = Matrix3.fromRows(r0, r1, r2);
        expect(m.row(0).x, 1);
        expect(m.row(0).y, 2);
        expect(m.row(0).z, 3);
        expect(m.row(1).x, 4);
        expect(m.row(2).x, 7);
      });
    });

    group('accessors', () {
      test('get and set work correctly', () {
        final m = Matrix3.zero();
        m.set(1, 2, 42);
        expect(m.get(1, 2), 42);
      });

      test('row returns correct vector', () {
        final m = Matrix3([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        expect(m.row(1).toList(), [4, 5, 6]);
      });

      test('column returns correct vector', () {
        final m = Matrix3([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        expect(m.column(1).toList(), [2, 5, 8]);
      });
    });

    group('transform', () {
      test('identity transform leaves vector unchanged', () {
        final m = Matrix3.identity();
        const v = Vector3(1, 2, 3);
        final result = m.transform(v);
        expect(result.x, 1);
        expect(result.y, 2);
        expect(result.z, 3);
      });

      test('scaling matrix scales vector', () {
        final m = Matrix3([2, 0, 0, 0, 3, 0, 0, 0, 4]);
        const v = Vector3(1, 1, 1);
        final result = m.transform(v);
        expect(result.x, 2);
        expect(result.y, 3);
        expect(result.z, 4);
      });

      test('rotation matrix rotates correctly', () {
        // 90 degree rotation around z-axis
        final cos90 = math.cos(math.pi / 2);
        final sin90 = math.sin(math.pi / 2);
        final m = Matrix3([cos90, -sin90, 0, sin90, cos90, 0, 0, 0, 1]);
        const v = Vector3(1, 0, 0);
        final result = m.transform(v);
        expect(result.x, closeTo(0, 1e-10));
        expect(result.y, closeTo(1, 1e-10));
        expect(result.z, closeTo(0, 1e-10));
      });
    });

    group('matrix operations', () {
      test('matrix multiplication with identity', () {
        final m = Matrix3([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        final identity = Matrix3.identity();
        final result = m.multiply(identity);
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            expect(result.get(i, j), m.get(i, j));
          }
        }
      });

      test('matrix addition', () {
        final a = Matrix3([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        final b = Matrix3([9, 8, 7, 6, 5, 4, 3, 2, 1]);
        final c = a + b;
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            expect(c.get(i, j), 10);
          }
        }
      });

      test('matrix subtraction', () {
        final a = Matrix3([5, 5, 5, 5, 5, 5, 5, 5, 5]);
        final b = Matrix3([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        final c = a - b;
        expect(c.get(0, 0), 4);
        expect(c.get(1, 1), 0);
        expect(c.get(2, 2), -4);
      });

      test('scalar multiplication', () {
        final m = Matrix3([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        final scaled = m * 2;
        expect(scaled.get(0, 0), 2);
        expect(scaled.get(1, 1), 10);
        expect(scaled.get(2, 2), 18);
      });

      test('transpose', () {
        final m = Matrix3([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        final t = m.transpose;
        expect(t.get(0, 0), 1);
        expect(t.get(0, 1), 4);
        expect(t.get(0, 2), 7);
        expect(t.get(1, 0), 2);
        expect(t.get(1, 1), 5);
        expect(t.get(2, 0), 3);
      });
    });

    group('determinant', () {
      test('identity determinant is 1', () {
        expect(Matrix3.identity().determinant, 1);
      });

      test('zero matrix determinant is 0', () {
        expect(Matrix3.zero().determinant, 0);
      });

      test('scaling matrix determinant is product of scales', () {
        final m = Matrix3([2, 0, 0, 0, 3, 0, 0, 0, 4]);
        expect(m.determinant, 24); // 2 * 3 * 4
      });

      test('singular matrix determinant is 0', () {
        // Two identical rows
        final m = Matrix3([1, 2, 3, 1, 2, 3, 4, 5, 6]);
        expect(m.determinant, 0);
      });
    });

    group('inverse', () {
      test('identity inverse is identity', () {
        final inv = Matrix3.identity().inverse;
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            expect(inv.get(i, j), closeTo(i == j ? 1 : 0, 1e-10));
          }
        }
      });

      test('scaling matrix inverse', () {
        final m = Matrix3([2, 0, 0, 0, 4, 0, 0, 0, 5]);
        final inv = m.inverse;
        expect(inv.get(0, 0), closeTo(0.5, 1e-10));
        expect(inv.get(1, 1), closeTo(0.25, 1e-10));
        expect(inv.get(2, 2), closeTo(0.2, 1e-10));
      });

      test('M * M^-1 = I', () {
        final m = Matrix3([1, 2, 3, 0, 1, 4, 5, 6, 0]);
        final inv = m.inverse;
        final product = m.multiply(inv);
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            expect(product.get(i, j), closeTo(i == j ? 1 : 0, 1e-10));
          }
        }
      });

      test('singular matrix throws', () {
        final singular = Matrix3([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        expect(() => singular.inverse, throwsStateError);
      });
    });

    group('copy', () {
      test('copy creates independent copy', () {
        final m = Matrix3([1, 2, 3, 4, 5, 6, 7, 8, 9]);
        final c = m.copy();
        c.set(0, 0, 99);
        expect(m.get(0, 0), 1);
        expect(c.get(0, 0), 99);
      });
    });
  });

  group('solveLinearSystem3', () {
    test('solves simple system', () {
      // x = 1, y = 2, z = 3
      // x + y + z = 6
      // x - y + z = 2
      // x + y - z = 0
      final a = Matrix3([1, 1, 1, 1, -1, 1, 1, 1, -1]);
      const b = Vector3(6, 2, 0);
      final x = solveLinearSystem3(a, b);
      expect(x, isNotNull);
      expect(x!.x, closeTo(1, 1e-10));
      expect(x.y, closeTo(2, 1e-10));
      expect(x.z, closeTo(3, 1e-10));
    });

    test('solves identity system', () {
      final a = Matrix3.identity();
      const b = Vector3(5, 10, 15);
      final x = solveLinearSystem3(a, b);
      expect(x, isNotNull);
      expect(x!.x, closeTo(5, 1e-10));
      expect(x.y, closeTo(10, 1e-10));
      expect(x.z, closeTo(15, 1e-10));
    });

    test('returns null for singular matrix', () {
      // Two identical rows
      final a = Matrix3([1, 2, 3, 1, 2, 3, 4, 5, 6]);
      const b = Vector3(1, 1, 1);
      final x = solveLinearSystem3(a, b);
      expect(x, isNull);
    });
  });
}
