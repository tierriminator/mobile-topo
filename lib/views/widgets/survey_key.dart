import '../../models/cave.dart';

/// Stands for the survey data of a section and the cave it is in, as far
/// as station positions and how the survey is drawn depend on it: the
/// section, the surveys of all sections, the trips and the coordinate
/// system. Surveys and trip lists are never changed, only replaced, so they
/// are compared by identity, which is cheap even for large caves. Equal
/// keys mean what was computed from the data can be kept, for instance
/// while only a sketch changes.
class SurveyKey {
  final List<Object?> _parts;

  SurveyKey(Cave? cave, Section? section)
      : _parts = [
          section?.id,
          section?.survey,
          cave?.coordinateSystem,
          cave?.trips,
          for (final s in cave?.allSections ?? const <Section>[]) s.survey,
        ];

  @override
  bool operator ==(Object other) {
    if (other is! SurveyKey || other._parts.length != _parts.length) {
      return false;
    }
    for (var i = 0; i < _parts.length; i++) {
      if (_parts[i] != other._parts[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(_parts.length, _parts.first);
}
