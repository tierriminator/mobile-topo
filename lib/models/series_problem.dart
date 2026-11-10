import 'series_range.dart';
import 'trip.dart';

/// Something wrong with a trip's reserved series; see
/// [Cave.seriesProblemOf]. Edits may leave a trip in such a state, so it
/// is pointed out rather than prevented.
sealed class SeriesProblem {
  const SeriesProblem();
}

/// A closed range ending before it starts
class RangeEndsBeforeStart extends SeriesProblem {
  final SeriesRange range;
  const RangeEndsBeforeStart(this.range);
}

/// An open range other than the trip's last
class OpenRangeNotLast extends SeriesProblem {
  final SeriesRange range;
  const OpenRangeNotLast(this.range);
}

/// Two closed ranges of the trip sharing a series
class RangesOverlap extends SeriesProblem {
  final SeriesRange range, other;
  const RangesOverlap(this.range, this.other);
}

/// A closed range sharing a series with a closed range of [trip]
class RangeOverlapsOtherTrip extends SeriesProblem {
  final SeriesRange range, other;
  final Trip trip;
  const RangeOverlapsOtherTrip(this.range, this.other, this.trip);
}

/// A closed range holding [series], which [trip] started
class RangeHoldsOtherSeries extends SeriesProblem {
  final SeriesRange range;
  final num series;
  final Trip trip;
  const RangeHoldsOtherSeries(this.range, this.series, this.trip);
}

/// A series the trip started that its reserved series do not allow
class SeriesOutsideRanges extends SeriesProblem {
  final num series;
  const SeriesOutsideRanges(this.series);
}

/// A series the trip started in a closed range [reservedBy] reserves
class SeriesReservedByOther extends SeriesProblem {
  final num series;
  final Trip reservedBy;
  const SeriesReservedByOther(this.series, this.reservedBy);
}
