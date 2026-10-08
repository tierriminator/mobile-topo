import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_topo/models/side_view.dart';
import 'package:mobile_topo/models/survey.dart';

SideView _sideView(Survey survey) =>
    SideView.of(survey, survey.computeStationPositions());

Matcher _near(Offset expected) => isA<Offset>()
    .having((o) => (o - expected).distance, 'distance to $expected',
        lessThan(1e-9));

void main() {
  test('shots run left to right in survey direction, whatever their azimuth',
      () {
    final view = _sideView(const Survey(
      stretches: [
        MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
        MeasuredDistance(Point(1, 1), Point(1, 2), 4, 270, 0),
      ],
      referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 100)],
    ));

    expect(view.stationPositions[const Point(1, 0)], _near(const Offset(0, -100)));
    expect(view.stationPositions[const Point(1, 1)], _near(const Offset(5, -100)));
    expect(view.stationPositions[const Point(1, 2)], _near(const Offset(9, -100)));
  });

  test('a backward shot still progresses to the right', () {
    // Measured from the new station 1.1 back to 1.0
    final view = _sideView(const Survey(
      stretches: [MeasuredDistance(Point(1, 1), Point(1, 0), 5, 270, 0)],
      referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 0)],
    ));

    expect(view.stationPositions[const Point(1, 1)], _near(const Offset(5, 0)));
  });

  test('shots keep their horizontal length and stations their altitude', () {
    final view = _sideView(const Survey(
      stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 10, 0, 30)],
      referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 0)],
    ));

    // cos 30° * 10 along, sin 30° * 10 up
    expect(view.stationPositions[const Point(1, 1)],
        _near(const Offset(8.660254037844387, -5)));
  });

  test('a station reached from the start runs leftwards towards it', () {
    // The reference point is at the end of the series
    final view = _sideView(const Survey(
      stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0)],
      referencePoints: [ReferencePoint(Point(1, 1), 0, 0, 0)],
    ));

    expect(view.stationPositions[const Point(1, 0)], _near(const Offset(-5, 0)));
  });

  test('splays are projected onto the direction of the survey', () {
    final view = _sideView(const Survey(
      stretches: [
        MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0),
        // Ahead, sideways and behind at the new station
        MeasuredDistance(Point(1, 1), null, 2, 90, 0),
        MeasuredDistance(Point(1, 1), null, 2, 0, 0),
        MeasuredDistance(Point(1, 1), null, 2, 270, 0),
        // Straight up
        MeasuredDistance(Point(1, 1), null, 3, 0, 90),
      ],
      referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 0)],
    ));
    final splays = view.splayEnd;

    expect(splays(const MeasuredDistance(Point(1, 1), null, 2, 90, 0)),
        _near(const Offset(7, 0)));
    expect(splays(const MeasuredDistance(Point(1, 1), null, 2, 0, 0)),
        _near(const Offset(5, 0)));
    expect(splays(const MeasuredDistance(Point(1, 1), null, 2, 270, 0)),
        _near(const Offset(3, 0)));
    expect(splays(const MeasuredDistance(Point(1, 1), null, 3, 0, 90)),
        _near(const Offset(5, -3)));
  });

  test('splays at the start station follow the first shot from it', () {
    final view = _sideView(const Survey(
      stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 5, 180, 0)],
      referencePoints: [ReferencePoint(Point(1, 0), 0, 0, 0)],
    ));

    // Pointing back up the passage, away from 1.1
    expect(view.splayEnd(const MeasuredDistance(Point(1, 0), null, 2, 0, 0)),
        _near(const Offset(-2, 0)));
  });

  test('a second reference point in the same network does not move it', () {
    final view = _sideView(const Survey(
      stretches: [MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0)],
      referencePoints: [
        ReferencePoint(Point(1, 0), 0, 0, 0),
        ReferencePoint(Point(1, 1), 5, 0, 0),
      ],
    ));

    expect(view.stationPositions[const Point(1, 1)], _near(const Offset(5, 0)));
  });
}
