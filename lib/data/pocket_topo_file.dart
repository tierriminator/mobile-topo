import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:uuid/uuid.dart';

import '../models/cave.dart';
import '../models/cross_section.dart';
import '../models/side_view.dart';
import '../models/sketch.dart';
import '../models/survey.dart';
import '../models/trip.dart';

/// The contents of a PocketTopo `.top` file, converted to this app's models:
/// what a section and the trips its stretches refer to need.
class PocketTopoImport {
  /// The file's trips, in the order of the file
  final List<Trip> trips;

  /// The file's stretches and reference points. Repeated measurements of a
  /// survey shot are averaged into one stretch.
  final Survey survey;
  final Sketch outlineSketch;
  final Sketch sideViewSketch;

  /// Measurements left out because they belong to no station
  final int skippedShots;

  const PocketTopoImport({
    required this.trips,
    required this.survey,
    required this.outlineSketch,
    required this.sideViewSketch,
    required this.skippedShots,
  });

  /// This import with each trip that matches one of [existing], or an
  /// earlier trip of the file, replaced by that trip: [trips] keeps only the
  /// trips to add. Trips match if they are on the same day with the same
  /// declination and comment, as when several files were surveyed on one
  /// trip.
  PocketTopoImport withTripsFrom(List<Trip> existing) {
    final known = [...existing];
    final added = <Trip>[];
    final replaced = <String, String>{};
    for (final trip in trips) {
      final same = known.where((t) => _isSameTrip(t, trip)).firstOrNull;
      if (same != null) {
        replaced[trip.id] = same.id;
      } else {
        known.add(trip);
        added.add(trip);
      }
    }
    return PocketTopoImport(
      trips: added,
      survey: survey.copyWith(stretches: [
        for (final s in survey.stretches)
          switch (replaced[s.tripId]) {
            final id? => s.copyWith(tripId: id),
            null => s,
          },
      ]),
      outlineSketch: outlineSketch,
      sideViewSketch: sideViewSketch,
      skippedShots: skippedShots,
    );
  }

  static bool _isSameTrip(Trip a, Trip b) =>
      a.date.year == b.date.year &&
      a.date.month == b.date.month &&
      a.date.day == b.date.day &&
      (a.declination - b.declination).abs() < 1e-9 &&
      a.comment.trim() == b.comment.trim();
}

/// Reads PocketTopo `.top` files, version 3, as described in
/// `docs/pocket_topo/PocketTopoFileFormat.txt`
class PocketTopoFile {
  /// Reads [bytes] of a `.top` file. [newId] makes the IDs of the trips.
  /// Throws a [FormatException] if the bytes are not a readable `.top` file.
  static PocketTopoImport read(Uint8List bytes, {String Function()? newId}) {
    try {
      return _TopReader(bytes, newId ?? const Uuid().v4).read();
    } on RangeError {
      throw const FormatException('The PocketTopo file ends unexpectedly');
    }
  }
}

/// A shot as stored in the file, before repeated measurements are merged
class _Shot {
  final Point? from, to;
  final double distance, azimuth, inclination;
  final bool flipped;
  final String? tripId;
  final String? comment;

  const _Shot(this.from, this.to, this.distance, this.azimuth,
      this.inclination, this.flipped, this.tripId, this.comment);
}

/// A drawing as stored in the file: positions relative to the first
/// station, with the y axis pointing down
class _Drawing {
  final List<Stroke> strokes;
  final List<CrossSection> crossSections;

  const _Drawing(this.strokes, this.crossSections);

  /// The drawing moved by [offset] into world coordinates
  Sketch shiftedBy(Offset offset) => Sketch(
        strokes: [
          for (final s in strokes)
            Stroke(
              points: [for (final p in s.points) p + offset],
              color: s.color,
            ),
        ],
        crossSections: [
          for (final c in crossSections)
            CrossSection(
              station: c.station,
              position: c.position + offset,
              kind: c.kind,
            ),
        ],
      );
}

class _TopReader {
  final ByteData _data;
  final String Function() _newId;
  int _offset = 0;

  _TopReader(Uint8List bytes, this._newId)
      : _data = ByteData.sublistView(bytes);

  /// Station ID of shots without a station
  static const int _undefinedId = 0x80000000;

  /// Added to plain station numbers
  static const int _numberBase = 0x80000001;

  /// Drawing colors by their number in the file
  static const List<Color> _colors = [
    SketchColors.black,
    SketchColors.gray,
    SketchColors.brown,
    SketchColors.blue,
    SketchColors.red,
    SketchColors.green,
    SketchColors.orange,
  ];

  PocketTopoImport read() {
    if (_byte() != 0x54 || _byte() != 0x6F || _byte() != 0x70) {
      throw const FormatException('Not a PocketTopo file');
    }
    final version = _byte();
    if (version != 3) {
      throw FormatException('Unsupported PocketTopo file version: $version');
    }

    final trips = [for (var i = _int32(); i > 0; i--) _trip()];
    final shots = [for (var i = _int32(); i > 0; i--) _shot(trips)];
    final references =
        [for (var i = _int32(); i > 0; i--) _reference()].nonNulls.toList();
    _mapping(); // Overview scroll position and scale
    final outline = _drawing();
    final sideView = _drawing();

    final (stretches, skipped) = _stretches(shots);
    final survey = Survey(stretches: stretches, referencePoints: references);
    final (outlineOrigin, sideViewOrigin) = _origins(survey, trips);

    return PocketTopoImport(
      trips: trips,
      survey: survey,
      outlineSketch: outline.shiftedBy(outlineOrigin),
      sideViewSketch: sideView.shiftedBy(sideViewOrigin),
      skippedShots: skipped,
    );
  }

  int _byte() => _data.getUint8(_offset++);

  int _int16() {
    final value = _data.getInt16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  int _int32() {
    final value = _data.getInt32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  int _uint32() {
    final value = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  int _int64() {
    final value = _data.getInt64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  /// A .NET string: its length in 7 bit groups, low group first, then the
  /// UTF-8 bytes
  String _string() {
    var length = 0;
    for (var shift = 0;; shift += 7) {
      final b = _byte();
      length |= (b & 0x7F) << shift;
      if (b & 0x80 == 0) break;
    }
    if (_offset + length > _data.lengthInBytes) {
      throw RangeError('String exceeds the file');
    }
    final text = utf8.decode(
        Uint8List.sublistView(_data, _offset, _offset + length),
        allowMalformed: true);
    _offset += length;
    return text;
  }

  /// An angle in degrees; the file divides the full circle into 2^16 units
  static double _degrees(int units) => units * 360 / 65536;

  /// A station ID, or null for none. Plain numbers have no series, so they
  /// become points of series 0.
  Point? _station() {
    final value = _uint32();
    if (value == _undefinedId) return null;
    if (value > _undefinedId) return Point(0, value - _numberBase);
    return Point(value >> 16, value & 0xFFFF);
  }

  /// A time in .NET ticks: 100 ns units since 1 January of year 1. PocketTopo
  /// stores the local time, so the result is the same wall clock time here.
  DateTime _time() {
    // Ticks of 1 January 1970
    const epochTicks = 621355968000000000;
    final utc = DateTime.fromMicrosecondsSinceEpoch(
        (_int64() - epochTicks) ~/ 10,
        isUtc: true);
    return DateTime(utc.year, utc.month, utc.day, utc.hour, utc.minute,
        utc.second, utc.millisecond, utc.microsecond);
  }

  Trip _trip() {
    final time = _time();
    final comment = _string();
    final declination = _degrees(_int16());
    return Trip(
      id: _newId(),
      date: DateTime(time.year, time.month, time.day),
      declination: declination,
      comment: comment,
      createdAt: time,
    );
  }

  _Shot _shot(List<Trip> trips) {
    final from = _station();
    final to = _station();
    final distance = _int32() / 1000;
    final azimuth = _degrees(_int16() & 0xFFFF);
    final inclination = _degrees(_int16());
    final flags = _byte();
    _byte(); // Roll of the device
    final tripIndex = _int16();
    final comment = flags & 2 != 0 ? _string() : null;
    return _Shot(
      from,
      to,
      distance,
      azimuth,
      inclination,
      flags & 1 != 0,
      tripIndex >= 0 && tripIndex < trips.length ? trips[tripIndex].id : null,
      comment == null || comment.trim().isEmpty ? null : comment.trim(),
    );
  }

  ReferencePoint? _reference() {
    final station = _station();
    final east = _int64() / 1000;
    final north = _int64() / 1000;
    final altitude = _int32() / 1000;
    final comment = _string().trim();
    if (station == null) return null;
    return ReferencePoint(station, east, north, altitude,
        comment: comment.isEmpty ? null : comment);
  }

  /// A scroll position and scale, which the app does not keep
  void _mapping() {
    _point();
    _int32();
  }

  Offset _point() {
    final x = _int32() / 1000;
    final y = _int32() / 1000;
    return Offset(x, y);
  }

  _Drawing _drawing() {
    _mapping();
    final strokes = <Stroke>[];
    final crossSections = <CrossSection>[];
    for (var element = _byte(); element != 0; element = _byte()) {
      switch (element) {
        case 1:
          final points = [for (var i = _int32(); i > 0; i--) _point()];
          final colorIndex = _byte() - 1;
          final color = colorIndex >= 0 && colorIndex < _colors.length
              ? _colors[colorIndex]
              : SketchColors.black;
          // A single point is a dot: drawn as a line of no length
          if (points.length == 1) points.add(points.first);
          if (points.isNotEmpty) {
            strokes.add(Stroke(points: points, color: color));
          }
        case 3:
          final position = _point();
          final station = _station();
          final direction = _int32();
          if (station != null) {
            crossSections.add(CrossSection(
              station: station,
              position: position,
              kind: direction == -1
                  ? CrossSectionKind.horizontal
                  : CrossSectionKind.vertical,
            ));
          }
        default:
          throw FormatException('Unknown PocketTopo drawing element: $element');
      }
    }
    return _Drawing(strokes, crossSections);
  }

  /// The stretches of [shots]: PocketTopo keeps every measurement of a
  /// survey shot, which follow each other with the same stations; they are
  /// averaged into one. Also returns how many shots without a station were
  /// left out.
  static (List<MeasuredDistance>, int) _stretches(List<_Shot> shots) {
    final stretches = <MeasuredDistance>[];
    var skipped = 0;
    for (var i = 0; i < shots.length;) {
      final shot = shots[i];
      final from = shot.from;
      final to = shot.to;
      if (from != null && to != null) {
        var end = i + 1;
        while (end < shots.length &&
            shots[end].from == from &&
            shots[end].to == to) {
          end++;
        }
        stretches.add(_average(shots.sublist(i, end)));
        i = end;
        continue;
      }

      if (from != null) {
        stretches.add(MeasuredDistance(
            from, null, shot.distance, shot.azimuth, shot.inclination,
            tripId: shot.tripId, comment: shot.comment));
      } else if (to != null) {
        // Measured towards the station: the same splay, seen from it
        stretches.add(MeasuredDistance(to, null, shot.distance,
            (shot.azimuth + 180) % 360, -shot.inclination,
            tripId: shot.tripId, comment: shot.comment));
      } else {
        skipped++;
      }
      i++;
    }
    return (stretches, skipped);
  }

  /// One stretch from repeated measurements of a survey shot, with the
  /// directions averaged as vectors so azimuths around north average right
  static MeasuredDistance _average(List<_Shot> shots) {
    var east = 0.0, north = 0.0, up = 0.0, distance = 0.0;
    for (final s in shots) {
      final azimuth = s.azimuth * math.pi / 180;
      final inclination = s.inclination * math.pi / 180;
      east += math.cos(inclination) * math.sin(azimuth);
      north += math.cos(inclination) * math.cos(azimuth);
      up += math.sin(inclination);
      distance += s.distance;
    }
    final first = shots.first;
    if (shots.length == 1) {
      return MeasuredDistance(first.from!, first.to, first.distance,
          first.azimuth, first.inclination,
          tripId: first.tripId, comment: first.comment, flipped: first.flipped);
    }
    final length = math.sqrt(east * east + north * north + up * up);
    var azimuth = math.atan2(east, north) * 180 / math.pi;
    if (azimuth < 0) azimuth += 360;
    final inclination =
        math.asin((up / length).clamp(-1.0, 1.0)) * 180 / math.pi;
    return MeasuredDistance(
      first.from!,
      first.to,
      distance / shots.length,
      azimuth,
      inclination,
      tripId: first.tripId,
      comment: shots.map((s) => s.comment).nonNulls.firstOrNull,
      flipped: first.flipped,
    );
  }

  /// Where the station the drawings are relative to lies in the outline and
  /// in the side view: the first reference point, or the first station
  /// measured from if there is none, which is then placed at the origin
  static (Offset, Offset) _origins(Survey survey, List<Trip> trips) {
    final origin = survey.referencePoints.firstOrNull?.id ??
        survey.stretches.firstOrNull?.from;
    if (origin == null) return (Offset.zero, Offset.zero);

    final placed = survey.referencePoints.isEmpty
        ? survey.copyWith(
            referencePoints: [ReferencePoint(origin, 0, 0, 0)])
        : survey;
    final now = DateTime.now();
    final corrected =
        Cave(id: '', name: '', trips: trips, createdAt: now, modifiedAt: now)
            .corrected(placed);
    final positions = corrected.computeStationPositions();
    final position = positions[origin]!;
    final sideView = SideView.of(corrected, positions).stationPositions;
    return (
      Offset(position.east, -position.north),
      sideView[origin] ?? Offset(0, -position.altitude),
    );
  }
}
