import 'dart:math' as math;
import 'dart:ui';

import '../models/cave.dart';
import '../models/side_view.dart';
import '../models/sketch.dart';
import '../models/survey.dart';
import '../models/trip.dart';

/// Writes survey data for Therion (https://therion.speleo.sk) in two forms:
/// a survey file Therion reads directly, and the text PocketTopo exports for
/// xtherion, which also carries the sketches.
///
/// Both take the [Section]s to write from their [Cave], which provides the
/// trips and, for the sketches, the station positions: these are computed
/// over the whole cave, as in the sketch view.
class TherionFile {
  /// A Therion survey file (`.th`) titled [name]: the reference points as
  /// fixed stations, then one centreline per trip with its date, comment and
  /// declination and the trip's stretches in data order. Splays lead to the
  /// anonymous station `-`.
  static String survey(Cave cave, List<Section> sections, String name) {
    final out = StringBuffer()
      ..writeln('encoding utf-8')
      ..writeln('survey ${_surveyId(name)} -title ${_quoted(name)}');

    final references = [for (final s in sections) ...s.survey.referencePoints];
    if (references.isNotEmpty) {
      out
        ..writeln()
        ..writeln('  centreline');
      for (final ref in references) {
        out.writeln('    fix ${ref.id} ${_length(ref.east)} '
            '${_length(ref.north)} ${_length(ref.altitude)}'
            '${_comment(ref.comment)}');
      }
      out.writeln('  endcentreline');
    }

    for (final (trip, stretches) in _byTrip(cave, sections)) {
      out
        ..writeln()
        ..writeln('  centreline');
      if (trip != null) {
        out.writeln('    date ${_date(trip.date, '.')}');
        for (final line in trip.comment.split('\n')) {
          if (line.trim().isNotEmpty) out.writeln('    # ${line.trim()}');
        }
      }
      // Given even when zero, so Therion does not compute one of its own
      out
        ..writeln('    declination ${_angle(trip?.declination ?? 0)} degrees')
        ..writeln('    data normal from to length compass clino');
      bool? flipped;
      for (final s in stretches) {
        final to = s.to;
        if (to != null && s.flipped != flipped) {
          flipped = s.flipped;
          out.writeln('    extend ${s.flipped ? 'left' : 'right'}');
        }
        out.writeln('    ${s.from} ${to ?? '-'} ${_length(s.distance)} '
            '${_angle(s.azimut)} ${_angle(s.inclination)}'
            '${_comment(s.comment)}');
      }
      out.writeln('  endcentreline');
    }

    out
      ..writeln()
      ..writeln('endsurvey');
    return out.toString();
  }

  /// The text PocketTopo's "Export ► Therion" writes (`.txt`), which
  /// xtherion imports: the reference points, the stretches by trip, and the
  /// outline and side view drawings with their stations and shots. Sketch
  /// coordinates are in metres with the y axis pointing up. The format has
  /// no place for comments, so they are left out.
  static String pocketTopoText(Cave cave, List<Section> sections) {
    final out = StringBuffer();

    final references = [for (final s in sections) ...s.survey.referencePoints];
    if (references.isNotEmpty) {
      out.writeln('FIX');
      for (final ref in references) {
        out.writeln([
          ref.id,
          _length(ref.east),
          _length(ref.north),
          _length(ref.altitude),
        ].join('\t'));
      }
    }

    for (final (trip, stretches) in _byTrip(cave, sections)) {
      out.writeln('TRIP');
      if (trip != null) out.writeln('DATE ${_date(trip.date, '-')}');
      out
        ..writeln('DECLINATION\t${_angle(trip?.declination ?? 0)}')
        ..writeln('DATA');
      // Splays carry the direction of the survey shot before them, so they
      // do not change the direction of the shots that follow
      var flipped = false;
      for (final s in stretches) {
        if (s.to != null) flipped = s.flipped;
        out.writeln([
          s.from,
          s.to ?? '',
          _angle(s.azimut),
          _angle(s.inclination),
          _length(s.distance),
          flipped ? '<' : '>',
        ].join('\t'));
      }
    }

    final caveSurvey = cave.combinedSurvey;
    final positions = caveSurvey.computeStationPositions();
    final survey = cave.corrected(Survey(
      stretches: [for (final s in sections) ...s.survey.stretches],
      referencePoints: [for (final s in sections) ...s.survey.referencePoints],
    ));

    _writeDrawing(
      out,
      'PLAN',
      survey,
      positions.map((id, p) => MapEntry(id, Offset(p.east, -p.north))),
      (splay) => _planSplayEnd(positions, splay),
      [for (final s in sections) s.outlineSketch],
    );
    final sideView = SideView.of(caveSurvey, positions);
    _writeDrawing(
      out,
      'ELEVATION',
      survey,
      sideView.stationPositions,
      sideView.splayEnd,
      [for (final s in sections) s.sideViewSketch],
    );
    return out.toString();
  }

  /// The stretches of [sections] grouped by trip, in the order of the
  /// cave's trips; stretches of no known trip come last. Within a trip,
  /// stretches keep the order of the sections and of their data.
  static List<(Trip?, List<MeasuredDistance>)> _byTrip(
      Cave cave, List<Section> sections) {
    final byTrip = <String?, List<MeasuredDistance>>{};
    for (final section in sections) {
      for (final stretch in section.survey.stretches) {
        final tripId = cave.findTrip(stretch.tripId)?.id;
        (byTrip[tripId] ??= []).add(stretch);
      }
    }
    return [
      for (final trip in cave.trips)
        if (byTrip[trip.id] case final stretches?) (trip, stretches),
      if (byTrip[null] case final stretches?) (null, stretches),
    ];
  }

  /// Writes one drawing of the PocketTopo text: the stations and shots of
  /// [survey] that have a position in [stations], then the strokes of
  /// [sketches]. Positions are in world coordinates, with y pointing down.
  static void _writeDrawing(
    StringBuffer out,
    String title,
    Survey survey,
    Map<Point, Offset> stations,
    Offset? Function(MeasuredDistance splay) splayEnd,
    List<Sketch> sketches,
  ) {
    String point(Offset p) => '${_length(p.dx)}\t${_length(-p.dy)}';

    out
      ..writeln(title)
      ..writeln('STATIONS');
    for (final station in survey.stations) {
      final position = stations[station];
      if (position != null) out.writeln('${point(position)}\t$station');
    }

    out.writeln('SHOTS');
    for (final stretch in survey.stretches) {
      final from = stations[stretch.from];
      final to = stretch.to;
      final end = to == null ? splayEnd(stretch) : stations[to];
      if (from != null && end != null) {
        out.writeln('${point(from)}\t${point(end)}');
      }
    }

    for (final sketch in sketches) {
      for (final stroke in sketch.strokes) {
        out.writeln('POLYLINE ${_colorName(stroke.color)}');
        for (final p in stroke.points) {
          out.writeln(point(p));
        }
      }
    }
  }

  /// The end of a splay in the plan, in world coordinates
  static Offset? _planSplayEnd(
      Map<Point, StationPosition> positions, MeasuredDistance splay) {
    final from = positions[splay.from];
    if (from == null) return null;
    final azimuth = splay.azimut.toDouble() * math.pi / 180;
    final horizontal = splay.distance.toDouble() *
        math.cos(splay.inclination.toDouble() * math.pi / 180);
    return Offset(from.east + horizontal * math.sin(azimuth),
        -(from.north + horizontal * math.cos(azimuth)));
  }

  /// PocketTopo's name of a drawing color
  static String _colorName(Color color) => switch (color) {
        SketchColors.gray => 'GRAY',
        SketchColors.brown => 'BROWN',
        SketchColors.blue => 'BLUE',
        SketchColors.red => 'RED',
        SketchColors.green => 'GREEN',
        SketchColors.orange => 'ORANGE',
        _ => 'BLACK',
      };

  /// [name] as a Therion keyword: letters, digits, `_`, `-` and `/`, not
  /// starting with `-`
  static String _surveyId(String name) {
    final id = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9_/-]+'), '_');
    if (id.isEmpty || id == '_') return 'survey';
    return id.startsWith('-') ? '_$id' : id;
  }

  /// [text] as a Therion string, which doubles its quotes
  static String _quoted(String text) =>
      '"${text.replaceAll('\n', ' ').replaceAll('"', '""')}"';

  /// [comment] as a Therion end of line comment, or nothing if there is none
  static String _comment(String? comment) =>
      comment == null ? '' : ' # ${comment.replaceAll('\n', ' ')}';

  static String _date(DateTime date, String separator) => [
        date.year.toString().padLeft(4, '0'),
        date.month.toString().padLeft(2, '0'),
        date.day.toString().padLeft(2, '0'),
      ].join(separator);

  static String _length(num metres) => metres.toStringAsFixed(3);

  static String _angle(num degrees) => degrees.toStringAsFixed(2);
}
