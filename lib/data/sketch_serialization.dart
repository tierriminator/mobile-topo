import 'dart:typed_data';
import 'dart:ui';

import '../models/cross_section.dart';
import '../models/sketch.dart';
import '../models/survey.dart';

/// Binary serialization for Sketch and Stroke classes.
/// Provides efficient storage format for sketch data.
class SketchSerializer {
  /// Binary format version written: 2 added cross sections
  static const int formatVersion = 2;

  /// Serialize a stroke to bytes.
  /// Format: [color:4][width:4][pointCount:4][points:N*8]
  static Uint8List strokeToBytes(Stroke stroke) {
    final buffer = ByteData(12 + stroke.points.length * 8);
    // ignore: deprecated_member_use
    buffer.setUint32(0, stroke.color.value, Endian.little);
    buffer.setFloat32(4, stroke.strokeWidth, Endian.little);
    buffer.setUint32(8, stroke.points.length, Endian.little);
    for (int i = 0; i < stroke.points.length; i++) {
      buffer.setFloat32(12 + i * 8, stroke.points[i].dx, Endian.little);
      buffer.setFloat32(12 + i * 8 + 4, stroke.points[i].dy, Endian.little);
    }
    return buffer.buffer.asUint8List();
  }

  /// Deserialize a stroke from bytes, returning the stroke and bytes consumed.
  static (Stroke, int) strokeFromBytes(Uint8List data, int offset) {
    final buffer = ByteData.view(data.buffer, data.offsetInBytes + offset);
    final colorValue = buffer.getUint32(0, Endian.little);
    final width = buffer.getFloat32(4, Endian.little);
    final pointCount = buffer.getUint32(8, Endian.little);
    final points = <Offset>[];
    for (int i = 0; i < pointCount; i++) {
      final dx = buffer.getFloat32(12 + i * 8, Endian.little);
      final dy = buffer.getFloat32(12 + i * 8 + 4, Endian.little);
      points.add(Offset(dx, dy));
    }
    final bytesConsumed = 12 + pointCount * 8;
    // ignore: deprecated_member_use
    return (
      Stroke(points: points, color: Color(colorValue), strokeWidth: width),
      bytesConsumed
    );
  }

  /// Size of a serialized cross section in bytes
  static const int _crossSectionSize = 25;

  /// Serialize a cross section to bytes.
  /// Format: [corridorId:8][pointId:8][x:4][y:4][kind:1]
  static Uint8List crossSectionToBytes(CrossSection crossSection) {
    final buffer = ByteData(_crossSectionSize);
    buffer.setFloat64(
        0, crossSection.station.corridorId.toDouble(), Endian.little);
    buffer.setFloat64(8, crossSection.station.pointId.toDouble(), Endian.little);
    buffer.setFloat32(16, crossSection.position.dx, Endian.little);
    buffer.setFloat32(20, crossSection.position.dy, Endian.little);
    buffer.setUint8(24, crossSection.kind.index);
    return buffer.buffer.asUint8List();
  }

  /// Deserialize a cross section from bytes at [offset]
  static CrossSection crossSectionFromBytes(Uint8List data, int offset) {
    final buffer = ByteData.view(data.buffer, data.offsetInBytes + offset);
    return CrossSection(
      station: Point(
        _stationNumber(buffer.getFloat64(0, Endian.little)),
        _stationNumber(buffer.getFloat64(8, Endian.little)),
      ),
      position: Offset(
        buffer.getFloat32(16, Endian.little),
        buffer.getFloat32(20, Endian.little),
      ),
      kind: CrossSectionKind.values[buffer.getUint8(24)],
    );
  }

  /// A station number read back as an int if it is whole, as station IDs
  /// usually are, so it prints as "1.2" rather than "1.0.2.0"
  static num _stationNumber(double value) =>
      value == value.roundToDouble() ? value.toInt() : value;

  /// Serialize a sketch to bytes.
  /// Format: [version:1][strokeCount:4][strokes...]
  ///         [crossSectionCount:4][crossSections...]
  static Uint8List sketchToBytes(Sketch sketch) {
    final parts = <Uint8List>[
      for (final stroke in sketch.strokes) strokeToBytes(stroke),
    ];
    final strokesSize = parts.fold(0, (size, bytes) => size + bytes.length);
    final crossSectionsSize = sketch.crossSections.length * _crossSectionSize;

    final result = Uint8List(5 + strokesSize + 4 + crossSectionsSize);
    result[0] = formatVersion;
    final view = ByteData.view(result.buffer);
    view.setUint32(1, sketch.strokes.length, Endian.little);

    int offset = 5;
    for (final bytes in parts) {
      result.setRange(offset, offset + bytes.length, bytes);
      offset += bytes.length;
    }

    view.setUint32(offset, sketch.crossSections.length, Endian.little);
    offset += 4;
    for (final crossSection in sketch.crossSections) {
      result.setRange(offset, offset + _crossSectionSize,
          crossSectionToBytes(crossSection));
      offset += _crossSectionSize;
    }

    return result;
  }

  /// Deserialize a sketch from bytes. Version 1 sketches have strokes only.
  static Sketch sketchFromBytes(Uint8List data) {
    if (data.isEmpty) return const Sketch();

    final version = data[0];
    if (version != 1 && version != formatVersion) {
      throw FormatException('Unknown sketch format version: $version');
    }

    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final strokeCount = view.getUint32(1, Endian.little);

    final strokes = <Stroke>[];
    int offset = 5;
    for (int i = 0; i < strokeCount; i++) {
      final (stroke, bytesConsumed) = strokeFromBytes(data, offset);
      strokes.add(stroke);
      offset += bytesConsumed;
    }
    if (version == 1) return Sketch(strokes: strokes);

    final crossSectionCount = view.getUint32(offset, Endian.little);
    offset += 4;
    final crossSections = [
      for (int i = 0; i < crossSectionCount; i++)
        crossSectionFromBytes(data, offset + i * _crossSectionSize),
    ];

    return Sketch(strokes: strokes, crossSections: crossSections);
  }
}
