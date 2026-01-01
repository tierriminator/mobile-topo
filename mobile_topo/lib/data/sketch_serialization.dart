import 'dart:typed_data';
import 'dart:ui';

import '../models/sketch.dart';

/// Binary serialization for Sketch and Stroke classes.
/// Provides efficient storage format for sketch data.
class SketchSerializer {
  /// Binary format version for forward compatibility
  static const int formatVersion = 1;

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

  /// Serialize a sketch to bytes.
  /// Format: [version:1][strokeCount:4][strokes...]
  static Uint8List sketchToBytes(Sketch sketch) {
    // Calculate total size
    int totalSize = 5; // version + stroke count
    final strokeBytes = <Uint8List>[];
    for (final stroke in sketch.strokes) {
      final bytes = strokeToBytes(stroke);
      strokeBytes.add(bytes);
      totalSize += bytes.length;
    }

    // Write to buffer
    final result = Uint8List(totalSize);
    result[0] = formatVersion;
    final view = ByteData.view(result.buffer);
    view.setUint32(1, sketch.strokes.length, Endian.little);

    int offset = 5;
    for (final bytes in strokeBytes) {
      result.setRange(offset, offset + bytes.length, bytes);
      offset += bytes.length;
    }

    return result;
  }

  /// Deserialize a sketch from bytes.
  static Sketch sketchFromBytes(Uint8List data) {
    if (data.isEmpty) return const Sketch();

    final version = data[0];
    if (version != formatVersion) {
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

    return Sketch(strokes: strokes);
  }
}
