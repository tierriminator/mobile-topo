import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/models/survey.dart';

void main() {
  group('Survey.lastStation', () {
    Point? lastStation(List<MeasuredDistance> stretches,
            [List<ReferencePoint> referencePoints = const []]) =>
        Survey(stretches: stretches, referencePoints: referencePoints)
            .lastStation;

    test('is null for an empty survey', () {
      expect(lastStation([]), isNull);
    });

    test('is the last reference point without stretches', () {
      expect(lastStation([], [const ReferencePoint(Point(1, 0), 0, 0, 0)]),
          const Point(1, 0));
    });

    test('is the To station of a final forward shot', () {
      expect(
        lastStation([
          const MeasuredDistance(Point(1, 0), Point(1, 1), 5, 0, 0),
          const MeasuredDistance(Point(1, 1), Point(1, 2), 5, 0, 0),
        ]),
        const Point(1, 2),
      );
    });

    test('is the From station of a final backward shot', () {
      expect(
        lastStation([
          const MeasuredDistance(Point(1, 0), Point(1, 1), 5, 0, 0),
          const MeasuredDistance(Point(1, 2), Point(1, 1), 5, 180, 0),
        ]),
        const Point(1, 2),
      );
    });

    test('is the From station of a final cross section', () {
      expect(
        lastStation([
          const MeasuredDistance(Point(1, 0), Point(1, 1), 5, 0, 0),
          const MeasuredDistance(Point(1, 0), null, 2, 90, 0),
        ]),
        const Point(1, 0),
      );
    });

    test('is the To station of a final shot between known stations', () {
      expect(
        lastStation([
          const MeasuredDistance(Point(1, 0), Point(1, 1), 5, 0, 0),
          const MeasuredDistance(Point(1, 1), Point(1, 2), 5, 90, 0),
          const MeasuredDistance(Point(1, 2), Point(1, 0), 7, 225, 0),
        ]),
        const Point(1, 0),
      );
    });
  });
}
