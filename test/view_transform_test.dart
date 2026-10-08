import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/views/widgets/view_transform.dart';

void main() {
  const size = Size(400, 300);

  test('world and screen coordinates convert back and forth', () {
    const transform = ViewTransform(scale: 10, offset: Offset(5, -5));
    const world = Offset(3, 4);

    final screen = transform.worldToScreen(world, size);

    expect(screen, const Offset(200 + 5 + 30, 150 - 5 + 40));
    expect(transform.screenToWorld(screen, size), world);
  });

  group('pinched', () {
    test('zooms in without limit and pans', () {
      final pinched = const ViewTransform(scale: 100)
          .pinched(1000, const Offset(10, 20));

      expect(pinched.scale, 100000);
      expect(pinched.offset, const Offset(10, 20));
    });

    test('stops zooming out at the minimum scale', () {
      final pinched =
          const ViewTransform(scale: 10).pinched(0.01, Offset.zero);

      expect(pinched.scale, ViewTransform.minScale);
    });
  });

  test('zooming keeps the world point under the cursor in place', () {
    const transform = ViewTransform(scale: 10, offset: Offset(7, 3));
    const cursor = Offset(320, 90);
    final worldUnderCursor = transform.screenToWorld(cursor, size);

    final zoomed = transform.zoomedAt(cursor, size, 3);

    expect(zoomed.scale, 30);
    final moved = zoomed.worldToScreen(worldUnderCursor, size) - cursor;
    expect(moved.distance, lessThan(1e-9));
  });

  test('scrolling up zooms in and scrolling down zooms out', () {
    const transform = ViewTransform(scale: 100);
    PointerScrollEvent scroll(double dy) => PointerScrollEvent(
        position: const Offset(200, 150), scrollDelta: Offset(0, dy));

    expect(transform.scrolled(scroll(-10), size).scale, closeTo(110, 1e-9));
    expect(transform.scrolled(scroll(10), size).scale, closeTo(90, 1e-9));
  });

  group('centeredOn', () {
    test('centres the bounding box of the points', () {
      final centred = const ViewTransform(scale: 10)
          .centeredOn(const [Offset(0, 0), Offset(4, 2), Offset(2, -6)]);

      expect(centred.worldToScreen(const Offset(2, -2), size),
          size.center(Offset.zero));
    });

    test('leaves the transform unchanged without points', () {
      const transform = ViewTransform(scale: 10, offset: Offset(1, 2));

      expect(transform.centeredOn(const []), transform);
    });
  });

  group('scaleLabel', () {
    test('rounds ratios of at least 1:1', () {
      expect(const ViewTransform(scale: 20).scaleLabel, '1:50');
    });

    test('keeps two significant digits beyond 1:1', () {
      expect(const ViewTransform(scale: 6000).scaleLabel, '1:0.17');
    });
  });
}
