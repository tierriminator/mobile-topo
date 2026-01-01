import 'dart:typed_data';
import 'dart:ui';

/// A single stroke (polyline) in the sketch
class Stroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  const Stroke({
    required this.points,
    required this.color,
    this.strokeWidth = 2.0,
  });

  /// Create a copy with an additional point
  Stroke addPoint(Offset point) {
    return Stroke(
      points: [...points, point],
      color: color,
      strokeWidth: strokeWidth,
    );
  }

  /// Check if this stroke is empty
  bool get isEmpty => points.isEmpty;

  /// Check if this stroke has enough points to be visible
  bool get isVisible => points.length >= 2;

  /// Serialize this stroke to bytes.
  /// Format: [color:4][width:4][pointCount:4][points:N*8]
  Uint8List toBytes() {
    final buffer = ByteData(12 + points.length * 8);
    // ignore: deprecated_member_use
    buffer.setUint32(0, color.value, Endian.little);
    buffer.setFloat32(4, strokeWidth, Endian.little);
    buffer.setUint32(8, points.length, Endian.little);
    for (int i = 0; i < points.length; i++) {
      buffer.setFloat32(12 + i * 8, points[i].dx, Endian.little);
      buffer.setFloat32(12 + i * 8 + 4, points[i].dy, Endian.little);
    }
    return buffer.buffer.asUint8List();
  }

  /// Deserialize a stroke from bytes, returning the stroke and bytes consumed.
  static (Stroke, int) fromBytes(Uint8List data, int offset) {
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

  /// Split this stroke by removing points near the eraser position.
  /// Returns a list of remaining stroke segments (may be empty, one, or multiple).
  List<Stroke> eraseAt(Offset eraserPos, double threshold) {
    if (points.isEmpty) return [];

    final segments = <Stroke>[];
    var currentSegmentPoints = <Offset>[];

    for (final point in points) {
      if ((point - eraserPos).distance < threshold) {
        // Point is within eraser range - end current segment
        if (currentSegmentPoints.length >= 2) {
          segments.add(Stroke(
            points: List.from(currentSegmentPoints),
            color: color,
            strokeWidth: strokeWidth,
          ));
        }
        currentSegmentPoints = [];
      } else {
        // Point is outside eraser range - add to current segment
        currentSegmentPoints.add(point);
      }
    }

    // Add final segment if it has enough points
    if (currentSegmentPoints.length >= 2) {
      segments.add(Stroke(
        points: List.from(currentSegmentPoints),
        color: color,
        strokeWidth: strokeWidth,
      ));
    }

    return segments;
  }
}

/// A collection of strokes forming a complete sketch
class Sketch {
  final List<Stroke> strokes;

  const Sketch({this.strokes = const []});

  /// Create a copy with an additional stroke
  Sketch addStroke(Stroke stroke) {
    if (!stroke.isVisible) return this;
    return Sketch(strokes: [...strokes, stroke]);
  }

  /// Create a copy without the last stroke (for undo)
  Sketch removeLastStroke() {
    if (strokes.isEmpty) return this;
    return Sketch(strokes: strokes.sublist(0, strokes.length - 1));
  }

  /// Create a copy without the specified stroke
  Sketch removeStroke(Stroke stroke) {
    return Sketch(strokes: strokes.where((s) => s != stroke).toList());
  }

  /// Erase at a point - splits any strokes that pass through the eraser area.
  /// Returns null if nothing was erased, otherwise returns the new Sketch.
  Sketch? eraseAt(Offset point, double threshold) {
    bool anyChanged = false;
    final newStrokes = <Stroke>[];

    for (final stroke in strokes) {
      // Check if any point in this stroke is near the eraser
      bool strokeAffected = false;
      for (final p in stroke.points) {
        if ((p - point).distance < threshold) {
          strokeAffected = true;
          break;
        }
      }

      if (strokeAffected) {
        anyChanged = true;
        // Split the stroke and add remaining segments
        final segments = stroke.eraseAt(point, threshold);
        newStrokes.addAll(segments);
      } else {
        // Stroke not affected, keep as is
        newStrokes.add(stroke);
      }
    }

    if (!anyChanged) return null;
    return Sketch(strokes: newStrokes);
  }

  /// Find stroke near a given point (for eraser)
  Stroke? findStrokeNear(Offset point, double threshold) {
    for (final stroke in strokes.reversed) {
      for (final p in stroke.points) {
        if ((p - point).distance < threshold) {
          return stroke;
        }
      }
    }
    return null;
  }

  /// Check if sketch is empty
  bool get isEmpty => strokes.isEmpty;

  /// Get bounding box of all strokes (for export)
  Rect? get bounds {
    if (isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final stroke in strokes) {
      for (final point in stroke.points) {
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      }
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Binary format version for forward compatibility
  static const int _formatVersion = 1;

  /// Serialize this sketch to bytes.
  /// Format: [version:1][strokeCount:4][strokes...]
  Uint8List toBytes() {
    // Calculate total size
    int totalSize = 5; // version + stroke count
    final strokeBytes = <Uint8List>[];
    for (final stroke in strokes) {
      final bytes = stroke.toBytes();
      strokeBytes.add(bytes);
      totalSize += bytes.length;
    }

    // Write to buffer
    final result = Uint8List(totalSize);
    result[0] = _formatVersion;
    final view = ByteData.view(result.buffer);
    view.setUint32(1, strokes.length, Endian.little);

    int offset = 5;
    for (final bytes in strokeBytes) {
      result.setRange(offset, offset + bytes.length, bytes);
      offset += bytes.length;
    }

    return result;
  }

  /// Deserialize a sketch from bytes.
  factory Sketch.fromBytes(Uint8List data) {
    if (data.isEmpty) return const Sketch();

    final version = data[0];
    if (version != _formatVersion) {
      throw FormatException('Unknown sketch format version: $version');
    }

    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final strokeCount = view.getUint32(1, Endian.little);

    final strokes = <Stroke>[];
    int offset = 5;
    for (int i = 0; i < strokeCount; i++) {
      final (stroke, bytesConsumed) = Stroke.fromBytes(data, offset);
      strokes.add(stroke);
      offset += bytesConsumed;
    }

    return Sketch(strokes: strokes);
  }
}

/// Available drawing colors (matching PocketTopo)
class SketchColors {
  static const Color black = Color(0xFF000000);
  static const Color brown = Color(0xFF8B4513);
  static const Color gray = Color(0xFF808080);
  static const Color blue = Color(0xFF0000FF);
  static const Color red = Color(0xFFFF0000);
  static const Color green = Color(0xFF008000);

  static const List<Color> all = [black, brown, gray, blue, red, green];
}

/// Drawing mode for the sketch view
enum SketchMode {
  move,    // Pan/zoom only, no drawing
  draw,    // Drawing with selected color
  erase,   // Erase parts of strokes by swiping
}
