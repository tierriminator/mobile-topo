class Point {
  final num corridorId, pointId;
  const Point(this.corridorId, this.pointId);
}

class MeasuredDistance {
  final Point from, to;
  final num distance, azimut, inclination;
  const MeasuredDistance(
      this.from, this.to, this.distance, this.azimut, this.inclination);
}
