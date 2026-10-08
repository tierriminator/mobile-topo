import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/cave.dart';
import '../../models/trip.dart';
import '../trip_page.dart';

/// Lets the user pick one of the trips of [cave]: a calendar offers the days
/// with a trip, and if several trips took place on the chosen day, a list of
/// them follows. The day and trip with [currentTripId] are preselected.
/// Returns null if the user cancels.
Future<Trip?> pickTrip(
  BuildContext context,
  Cave cave, {
  String? currentTripId,
}) async {
  final trips = cave.trips;
  if (trips.isEmpty) return null;
  final current = cave.findTrip(currentTripId);
  final days = {for (final t in trips) DateUtils.dateOnly(t.date)};
  final firstDay = days.reduce((a, b) => a.isBefore(b) ? a : b);
  final lastDay = days.reduce((a, b) => a.isAfter(b) ? a : b);
  final today = DateUtils.dateOnly(DateTime.now());

  final day = await showDatePicker(
    context: context,
    initialDate: current?.date,
    firstDate: firstDay,
    // Without a current trip the calendar opens at today, which must lie
    // in range
    lastDate: today.isAfter(lastDay) ? today : lastDay,
    selectableDayPredicate: days.contains,
    initialEntryMode: DatePickerEntryMode.calendarOnly,
  );
  if (day == null || !context.mounted) return null;

  // Newest first, so the active trip leads the list
  final onDay = [
    for (final t in trips.reversed)
      if (DateUtils.isSameDay(t.date, day)) t,
  ];
  if (onDay.length == 1) return onDay.single;
  return _pickTripOfDay(context, cave, day, onDay, current);
}

/// Lists the [trips] of [day], which share their date, by ID and comment
Future<Trip?> _pickTripOfDay(
  BuildContext context,
  Cave cave,
  DateTime day,
  List<Trip> trips,
  Trip? current,
) {
  final l10n = AppLocalizations.of(context)!;

  return showDialog<Trip>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(tripDateText(dialogContext, day)),
      children: [
        for (final trip in trips)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, trip),
            child: ListTile(
              selected: trip.id == current?.id,
              leading: Icon(
                trip.id == current?.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(trip.id),
              subtitle: _comment(trip).isEmpty ? null : Text(_comment(trip)),
              trailing: identical(cave.activeTrip, trip)
                  ? Text(l10n.tripActive)
                  : null,
            ),
          ),
      ],
    ),
  );
}

/// The first line of the trip's comment
String _comment(Trip trip) => trip.comment.split('\n').first.trim();
