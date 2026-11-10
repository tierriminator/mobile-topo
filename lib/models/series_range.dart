/// A range of series numbers a trip reserves for the new series it starts,
/// so teams surveying the same cave do not number theirs alike; see
/// [Survey.nextSeriesStart]
class SeriesRange {
  /// The first series of the range
  final int first;

  /// The last series of the range, or null if the range is open ended and
  /// takes every series from [first] on
  final int? last;

  const SeriesRange(this.first, [this.last]);

  bool get isOpen => last == null;

  /// Whether [series] lies in this range
  bool contains(num series) =>
      series >= first && (last == null || series <= last!);

  /// Whether this range and [other] share a series
  bool overlaps(SeriesRange other) =>
      (other.last == null || first <= other.last!) &&
      (last == null || other.first <= last!);

  @override
  bool operator ==(Object other) =>
      other is SeriesRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => last == null ? '$first–' : '$first–$last';

  Map<String, dynamic> toJson() => {
        'first': first,
        if (last != null) 'last': last,
      };

  factory SeriesRange.fromJson(Map<String, dynamic> json) =>
      SeriesRange(json['first'] as int, json['last'] as int?);
}
