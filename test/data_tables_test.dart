import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/settings.dart';
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

  group('comments', () {
    Future<List<(int, String)>> pumpCommentTable(
      WidgetTester tester, {
      String? comment,
      int readOnlyRows = 0,
      bool editMode = false,
    }) async {
      final changes = <(int, String)>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StretchesTable(
              data: [
                MeasuredDistance(const Point(1, 0), const Point(1, 1), 5, 90, 0,
                    comment: comment),
              ],
              readOnlyRows: readOnlyRows,
              editMode: editMode,
              onCommentChanged: (index, comment) =>
                  changes.add((index, comment)),
            ),
          ),
        ),
      );
      return changes;
    }

    testWidgets('a row with a comment shows a star', (tester) async {
      await pumpCommentTable(tester, comment: 'Big hall');
      expect(find.text('*'), findsOneWidget);
    });

    testWidgets('a row without a comment shows no star', (tester) async {
      await pumpCommentTable(tester);
      expect(find.text('*'), findsNothing);
    });

    testWidgets('the context menu edits the comment', (tester) async {
      final changes = await pumpCommentTable(tester);

      await tester.longPress(find.text('5.00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comment…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Big hall');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(changes, [(0, 'Big hall')]);
    });

    // The scroll bar may cover the comment field, so it opens nothing
    testWidgets('tapping the comment field does not open the comment',
        (tester) async {
      await pumpCommentTable(tester, comment: 'Big hall');

      await tester.tap(find.text('*'));
      await tester.pump();
      await tester.tap(find.text('*'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('edit mode hides the comment column', (tester) async {
      await pumpCommentTable(tester, comment: 'Big hall', editMode: true);
      expect(find.text('*'), findsNothing);
    });

    testWidgets('a read-only row without a comment opens no menu',
        (tester) async {
      await pumpCommentTable(tester, readOnlyRows: 1);

      await tester.longPress(find.text('5.00'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PopupMenuItem<String>), findsNothing);
    });

    testWidgets('a read-only row shows its comment without editing',
        (tester) async {
      final changes = await pumpCommentTable(tester,
          comment: 'Big hall', readOnlyRows: 1);

      await tester.longPress(find.text('5.00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comment…'));
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
    });
  });

  group('units', () {
    /// Shows a 5 m shot at 90° in feet and grad, in edit mode, and returns
    /// the stretches it is updated with
    Future<List<MeasuredDistance>> pumpFeetAndGrad(WidgetTester tester) async {
      final updates = <MeasuredDistance>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StretchesTable(
              data: const [MeasuredDistance(Point(1, 0), Point(1, 1), 5, 90, 0)],
              lengthUnit: LengthUnit.feet,
              angleUnit: AngleUnit.grad,
              editMode: true,
              onUpdate: (index, stretch) => updates.add(stretch),
            ),
          ),
        ),
      );
      return updates;
    }

    /// Edits the cell showing [cellText] to [text], or leaves it unchanged
    Future<void> editCell(WidgetTester tester, String cellText,
        [String? text]) async {
      await tester.tap(find.text(cellText));
      await tester.pumpAndSettle();
      if (text != null) await tester.enterText(find.byType(TextField), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    testWidgets('stretches are shown in the chosen units', (tester) async {
      await pumpFeetAndGrad(tester);
      expect(find.text('16.40'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('edited values are stored in meters and degrees',
        (tester) async {
      final updates = await pumpFeetAndGrad(tester);

      await editCell(tester, '16.40', '10');
      await editCell(tester, '100', '200');

      expect(updates[0].distance, closeTo(3.048, 1e-9));
      expect(updates[1].azimut, closeTo(180, 1e-9));
    });

    testWidgets('a cell left unchanged keeps its value', (tester) async {
      final updates = await pumpFeetAndGrad(tester);
      await editCell(tester, '16.40');
      expect(updates, isEmpty);
    });

    testWidgets('reference points are shown in the length unit',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ReferencePointsTable(
              data: [ReferencePoint(Point(1, 0), 100, 0, -3.048)],
              lengthUnit: LengthUnit.feet,
            ),
          ),
        ),
      );
      expect(find.text('328.084'), findsOneWidget);
      expect(find.text('-10'), findsOneWidget);
    });
  });
}
