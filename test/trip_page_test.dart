import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_topo/l10n/app_localizations.dart';
import 'package:mobile_topo/models/trip.dart';
import 'package:mobile_topo/views/trip_page.dart';

void main() {
  final trip = Trip(id: 't', date: DateTime(2026, 10, 8), createdAt: DateTime(2026));

  /// Opens the page for [trip] and returns the pending result of editTrip
  Future<Future<Trip?>> open(WidgetTester tester,
      {Future<bool> Function()? onDelete}) async {
    late Future<Trip?> result;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              result = editTrip(context, trip, onDelete: onDelete),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  /// Opens the page for [trip] and returns the result of editTrip once the
  /// page is left through the back button after [edit]
  Future<Trip?> editAndLeave(
      WidgetTester tester, Future<void> Function() edit) async {
    final result = await open(tester);
    await edit();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('leaving the page returns the edited trip', (tester) async {
    final edited = await editAndLeave(tester, () async {
      await tester.enterText(
          find.widgetWithText(TextField, 'Declination correction'), '-2.5');
      await tester.enterText(
          find.widgetWithText(TextField, 'Comment'), 'Anna, Ben');
    });

    expect(edited?.id, 't');
    expect(edited?.declination, -2.5);
    expect(edited?.comment, 'Anna, Ben');
    expect(edited?.createdAt, trip.createdAt);
  });

  testWidgets('leaving the page unchanged returns null', (tester) async {
    expect(await editAndLeave(tester, () async {}), isNull);
  });

  testWidgets('without onDelete there is no delete button', (tester) async {
    await open(tester);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('deleting closes the page and discards edits', (tester) async {
    final result = await open(tester, onDelete: () async => true);
    await tester.enterText(
        find.widgetWithText(TextField, 'Comment'), 'Anna, Ben');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(TripPage), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('the page stays open if the trip is not deleted',
      (tester) async {
    await open(tester, onDelete: () async => false);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(TripPage), findsOneWidget);
  });
}
