import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/survey.dart';
import 'package:mobile_topo/views/widgets/data_tables.dart';

void main() {
  Future<void> pumpTable(WidgetTester tester) {
    return tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StretchesTable(
            data: [MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0)],
          ),
        ),
      ),
    );
  }

  /// Cells highlighted on their own
  Finder highlightedCells() => find.descendant(
        of: find.byType(Table),
        matching: find.byType(ColoredBox),
      );

  /// Whether a whole row is highlighted
  bool rowHighlighted(WidgetTester tester) => tester
      .widgetList<Table>(find.byType(Table))
      .expand((table) => table.children)
      .any((row) => row.decoration != null);

  group('selection highlight', () {
    testWidgets('a station cell highlights only that cell', (tester) async {
      await pumpTable(tester);

      await tester.tap(find.text('1.1'));
      await tester.pump();

      expect(highlightedCells(), findsOneWidget);
      expect(
        find.descendant(of: highlightedCells(), matching: find.text('1.1')),
        findsOneWidget,
      );
      expect(rowHighlighted(tester), isFalse);
    });

    testWidgets('any other cell highlights the whole row', (tester) async {
      await pumpTable(tester);

      await tester.tap(find.text('5.00'));
      await tester.pump();

      expect(highlightedCells(), findsNothing);
      expect(rowHighlighted(tester), isTrue);
    });

    testWidgets('moving from a station cell to the row switches highlight',
        (tester) async {
      await pumpTable(tester);

      await tester.tap(find.text('1.0'));
      await tester.pump();
      await tester.tap(find.text('5.00'));
      await tester.pump();

      expect(highlightedCells(), findsNothing);
      expect(rowHighlighted(tester), isTrue);
    });

    testWidgets('tapping a selected cell again clears the selection',
        (tester) async {
      await pumpTable(tester);

      await tester.tap(find.text('1.0'));
      await tester.pump();
      await tester.tap(find.text('1.0'));
      await tester.pump();

      expect(highlightedCells(), findsNothing);
      expect(rowHighlighted(tester), isFalse);
    });
  });
}
