import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/trip.dart';

/// Short description of a trip: its date, followed by the first line of its
/// comment
String tripLabel(BuildContext context, Trip trip) {
  final date = MaterialLocalizations.of(context).formatMediumDate(trip.date);
  final comment = trip.comment.split('\n').first.trim();
  return comment.isEmpty ? date : '$date – $comment';
}

/// Opens the page for [trip] of [cave] and returns the trip as it is when
/// the page is left, or null if it is unchanged or was deleted. The page
/// offers deleting the trip if [onDelete] is given; see [TripPage.onDelete].
Future<Trip?> editTrip(
  BuildContext context,
  Cave cave,
  Trip trip, {
  Future<bool> Function()? onDelete,
}) async {
  final edited = await Navigator.of(context).push<Trip>(
    MaterialPageRoute(
      builder: (context) =>
          TripPage(cave: cave, trip: trip, onDelete: onDelete),
    ),
  );
  if (edited == null ||
      (edited.date == trip.date &&
          edited.declination == trip.declination &&
          edited.comment == trip.comment)) {
    return null;
  }
  return edited;
}

/// Page giving an overview of what was surveyed on a trip, and to change
/// the trip's date, declination and comment. Leaving the page pops it with
/// the edited trip.
class TripPage extends StatefulWidget {
  /// The cave the trip belongs to, whose data the overview is taken from
  final Cave cave;
  final Trip trip;

  /// Deletes the trip and returns whether it was deleted; the page closes
  /// if so. Without it, the page offers no delete button.
  final Future<bool> Function()? onDelete;

  const TripPage({
    super.key,
    required this.cave,
    required this.trip,
    this.onDelete,
  });

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  late DateTime _date;
  late final TextEditingController _declinationController;
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _date = widget.trip.date;
    final declination = widget.trip.declination;
    _declinationController = TextEditingController(
      text: declination == declination.toInt()
          ? declination.toInt().toString()
          : declination.toString(),
    );
    _commentController = TextEditingController(text: widget.trip.comment);
  }

  @override
  void dispose() {
    _declinationController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _delete() async {
    final deleted = await widget.onDelete!();
    // Closing with no result discards the edits of the deleted trip
    if (deleted && mounted) Navigator.of(context).pop();
  }

  Trip get _edited => widget.trip.copyWith(
        date: _date,
        declination: num.tryParse(_declinationController.text) ?? 0,
        comment: _commentController.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope<Trip>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_edited);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.tripTitle)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.straighten),
              title: Text(l10n.tripLength),
              trailing: Text(
                '${widget.cave.tripLength(widget.trip.id).toStringAsFixed(1)} m',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 24),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.tripDate,
                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                ),
                child: Text(
                  MaterialLocalizations.of(context).formatMediumDate(_date),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _declinationController,
              decoration: InputDecoration(
                labelText: l10n.tripDeclination,
                helperText: l10n.tripDeclinationHelp,
                helperMaxLines: 3,
                suffixText: '°',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: l10n.tripComment,
                hintText: l10n.tripCommentHint,
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: null,
            ),
            if (widget.onDelete != null) ...[
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete),
                label: Text(l10n.explorerDelete),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
