import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_topo/controllers/selection_state.dart';
import 'package:mobile_topo/models/cave.dart';
import 'package:mobile_topo/models/survey.dart';

void main() {
  final now = DateTime(2026);

  Section section(String id, [List<MeasuredDistance> stretches = const []]) =>
      Section(
        id: id,
        name: id,
        survey: Survey(stretches: stretches, referencePoints: const []),
        createdAt: now,
        modifiedAt: now,
      );

  Cave cave() => Cave(
        id: 'cave',
        name: 'Cave',
        sections: [section('root')],
        areas: [
          Area(
            id: 'area',
            name: 'Area',
            sections: [section('a1')],
            subAreas: [
              Area(
                id: 'sub',
                name: 'Sub',
                sections: [section('a2')],
                createdAt: now,
                modifiedAt: now,
              ),
            ],
            createdAt: now,
            modifiedAt: now,
          ),
        ],
        createdAt: now,
        modifiedAt: now,
      );

  const stretch =
      MeasuredDistance(Point(1, 0), Point(1, 1), 5.0, 90.0, 0.0);

  group('Cave', () {
    test('allSections includes sections nested in areas', () {
      expect(cave().allSections.map((s) => s.id), ['root', 'a1', 'a2']);
    });

    test('replaceSection replaces a deeply nested section', () {
      final updated = cave().replaceSection(section('a2', [stretch]));
      final a2 = updated.allSections.firstWhere((s) => s.id == 'a2');
      expect(a2.survey.stretches, [stretch]);
      expect(updated.allSections.length, 3);
    });
  });

  group('SelectionState', () {
    test('updateSection updates the section within the selected cave', () {
      final c = cave();
      final state = SelectionState()
        ..selectSection(c, c.allSections.firstWhere((s) => s.id == 'a1'));

      state.updateSection(section('a1', [stretch]));

      final a1 =
          state.selectedCave!.allSections.firstWhere((s) => s.id == 'a1');
      expect(a1.survey.stretches, [stretch]);
      expect(identical(a1, state.selectedSection), isTrue);
    });
  });
}
