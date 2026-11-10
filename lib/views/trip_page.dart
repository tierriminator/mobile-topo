import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/series_problem.dart';
import '../models/series_range.dart';
import '../models/settings.dart';
import '../models/survey.dart';
import '../models/trip.dart';
import 'widgets/number_format.dart';

/// Short description of a trip: its date, followed by the first line of its
/// comment
String tripLabel(BuildContext context, Trip trip) {
  final date = tripDateText(context, trip.date);
  final comment = trip.comment.split('\n').first.trim();
  return comment.isEmpty ? date : '$date – $comment';
}

/// What is wrong with a trip's reserved series, as told to the user
String seriesProblemText(BuildContext context, SeriesProblem problem) {
  final l10n = AppLocalizations.of(context)!;
  String label(Trip trip) => tripLabel(context, trip);
  return switch (problem) {
    RangeEndsBeforeStart(:final range) =>
      l10n.seriesProblemEndsBeforeStart('$range'),
    OpenRangeNotLast(:final range) => l10n.seriesProblemOpenNotLast('$range'),
    RangesOverlap(:final range, :final other) =>
      l10n.seriesProblemRangesOverlap('$range', '$other'),
    RangeOverlapsOtherTrip(:final range, :final other, :final trip) =>
      l10n.seriesProblemOverlapsOtherTrip('$range', '$other', label(trip)),
    RangeHoldsOtherSeries(:final range, :final series, :final trip) =>
      l10n.seriesProblemHoldsOtherSeries(
          '$range', formatNumber(series), label(trip)),
    SeriesOutsideRanges(:final series) =>
      l10n.seriesProblemOutsideRanges(formatNumber(series)),
    SeriesReservedByOther(:final series, :final reservedBy) =>
      l10n.seriesProblemReservedByOther(
          formatNumber(series), label(reservedBy)),
  };
}

/// A day as trips show it: with the year only if it is not the current one
String tripDateText(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  final format = date.year == DateTime.now().year
      ? DateFormat.MMMEd(locale)
      : DateFormat.yMMMEd(locale);
  return format.format(date);
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
          edited.autoDeclination == trip.autoDeclination &&
          edited.comment == trip.comment &&
          edited.activatedAt == trip.activatedAt &&
          listEquals(edited.reservedSeries, trip.reservedSeries))) {
    return null;
  }
  return edited;
}

/// Page giving an overview of what was surveyed on a trip, to change the
/// trip's date, declination, comment and reserved series, and to make it
/// the active trip.
/// Leaving the page pops it with the edited trip.
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
  /// The settings giving the units, which cannot change while the page is
  /// open
  late final Settings _settings;
  late DateTime _date;

  /// When the trip was made active on this page, if it was
  DateTime? _activatedAt;

  late bool _autoDeclination;

  /// The declination as first shown, in the angle unit
  late final String _declinationText;
  late final TextEditingController _declinationController;
  late final TextEditingController _commentController;

  /// The reserved series ranges as edited
  final _ranges = <_RangeFields>[];

  /// The surveys of all the cave's sections, giving the series in use
  late final Survey _caveSurvey;

  /// The trip each series of the cave belongs to; see [Cave.seriesTrips]
  late final Map<num, String> _seriesTrips;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsController>().settings;
    _date = widget.trip.date;
    _autoDeclination = widget.trip.autoDeclination;
    _declinationText =
        formatNumber(_settings.angleUnit.fromDegrees(widget.trip.declination));
    _declinationController = TextEditingController(text: _declinationText);
    _commentController = TextEditingController(text: widget.trip.comment);
    for (final range in widget.trip.reservedSeries) {
      _ranges.add(_RangeFields('${range.first}', '${range.last ?? ''}'));
    }
    final sections = widget.cave.allSections;
    _caveSurvey = Survey(stretches: [
      for (final section in sections) ...section.survey.stretches,
    ], referencePoints: [
      for (final section in sections) ...section.survey.referencePoints,
    ]);
    _seriesTrips = widget.cave.seriesTrips;
  }

  @override
  void dispose() {
    _declinationController.dispose();
    _commentController.dispose();
    for (final range in _ranges) {
      range.dispose();
    }
    super.dispose();
  }

  /// Adds an open ended range starting after the highest series in use or
  /// reserved by any trip
  void _addRange() {
    var first = _caveSurvey.maxSeries.floor() + 1;
    for (final range in [
      ...widget.cave.seriesReservedByOthers(widget.trip.id),
      for (final fields in _ranges) ?fields.range,
    ]) {
      first = math.max(first, math.max(range.first, range.last ?? 0) + 1);
    }
    setState(() => _ranges.add(_RangeFields('$first', '')));
  }

  void _removeRange(int index) {
    setState(() => _ranges.removeAt(index).dispose());
  }

  /// The ranges entered with a first series, which the trip keeps even if
  /// something is wrong with them; that is only pointed out
  Iterable<_RangeFields> get _enteredRanges =>
      _ranges.where((fields) => fields.range != null);

  /// The reserved series as edited
  List<SeriesRange> get _reservedSeries => [
        for (final fields in _enteredRanges) fields.range!,
      ];

  /// What is wrong with the range of [fields], if anything; see
  /// [Cave.rangeProblemOf]. A range without a first series is left out.
  String? _rangeError(AppLocalizations l10n, _RangeFields fields) {
    if (fields.isEmpty) return null;
    if (fields.range == null) return l10n.tripReservedSeriesFirstMissing;
    final index = _enteredRanges.toList().indexOf(fields);
    final problem = widget.cave.rangeProblemOf(
        widget.trip.copyWith(reservedSeries: _reservedSeries),
        index,
        _seriesTrips);
    return problem == null ? null : seriesProblemText(context, problem);
  }

  /// What the next new series of this trip is, or that there is none
  String _nextSeriesText(AppLocalizations l10n) {
    final next = _caveSurvey.nextSeriesStart(
      reserved: _reservedSeries,
      blocked: widget.cave.seriesReservedByOthers(widget.trip.id),
    );
    return next == null
        ? l10n.tripNextSeriesNone
        : l10n.tripNextSeries(formatNumber(next.corridorId));
  }

  /// Why the series the trip started do not fit its reserved series, if
  /// they do not; problems of the ranges themselves show at the ranges
  String? get _misplacedText {
    final problem = widget.cave.startedSeriesProblemOf(
        widget.trip.copyWith(reservedSeries: _reservedSeries), _seriesTrips);
    return problem == null ? null : seriesProblemText(context, problem);
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

  bool get _isActive =>
      _activatedAt != null || widget.cave.activeTrip?.id == widget.trip.id;

  /// Makes the trip the one new measurements are assigned to. A trip
  /// usually covers a single day, so one from another day is only made
  /// active after confirming.
  Future<void> _activate() async {
    if (!DateUtils.isSameDay(_date, DateTime.now())) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content:
              Text(l10n.tripMakeActiveOtherDay(tripDateText(context, _date))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.tripMakeActive),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _activatedAt = DateTime.now());
  }

  Future<void> _delete() async {
    final deleted = await widget.onDelete!();
    // Closing with no result discards the edits of the deleted trip
    if (deleted && mounted) Navigator.of(context).pop();
  }

  /// The declination in degrees. Unless its text was changed, it is the
  /// trip's own, which converting the shown, rounded value back would alter.
  num get _declination {
    final text = _declinationController.text;
    if (text == _declinationText) return widget.trip.declination;
    return _settings.angleUnit.toDegrees(num.tryParse(text) ?? 0);
  }

  Trip get _edited => widget.trip.copyWith(
        date: _date,
        declination: _declination,
        autoDeclination: _autoDeclination,
        comment: _commentController.text.trim(),
        activatedAt: _activatedAt,
        reservedSeries: _reservedSeries,
      );

  /// The automatic declination for the date shown, in degrees
  num get _computedDeclination => widget.cave
      .declinationOf(widget.trip.copyWith(date: _date, autoDeclination: true));

  /// Switches between automatic and manual declination. A manual
  /// declination not changed yet starts from the computed one.
  void _setAutoDeclination(bool auto) {
    setState(() {
      _autoDeclination = auto;
      if (!auto && _declinationController.text == _declinationText) {
        _declinationController.text = formatNumber(
            _settings.angleUnit.fromDegrees(_computedDeclination),
            decimals: 1);
      }
    });
  }

  /// The automatic declination in the angle unit
  String get _autoDeclinationText => '${formatNumber(
        _settings.angleUnit.fromDegrees(_computedDeclination),
        decimals: 1,
      )}${_settings.angleUnit.symbol}';

  /// A field for a series number of a reserved range, marked if the range
  /// is [invalid]
  Widget _seriesField(
    TextEditingController controller, {
    required String label,
    String? hint,
    required bool invalid,
  }) =>
      TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          error: invalid ? const SizedBox.shrink() : null,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
      );

  /// The fields of the reserved range at [index], with what is wrong with
  /// it below
  Widget _rangeRow(AppLocalizations l10n, int index, _RangeFields fields) {
    final error = _rangeError(l10n, fields);
    return Column(
      key: ObjectKey(fields),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _seriesField(
                fields.first,
                label: l10n.tripReservedSeriesFrom,
                invalid: error != null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _seriesField(
                fields.last,
                label: l10n.tripReservedSeriesTo,
                hint: l10n.tripReservedSeriesOpen,
                invalid: error != null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: l10n.tripReservedSeriesRemove,
                onPressed: () => _removeRange(index),
              ),
            ),
          ],
        ),
        if (error != null)
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lengthUnit = _settings.lengthUnit;

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
            // Tells apart trips of the same day; rarely needed, so kept small
            SelectableText(
              '${l10n.tripId}: ${widget.trip.id}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.straighten),
              title: Text(l10n.tripLength),
              trailing: Text(
                '${lengthUnit.fromMeters(widget.cave.tripLength(widget.trip.id)).toStringAsFixed(1)} '
                '${lengthUnit.symbol}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            // Shows that the trip is active instead once it is
            FilledButton.tonalIcon(
              onPressed: _isActive ? null : _activate,
              icon: Icon(_isActive ? Icons.check : Icons.play_arrow),
              label: Text(_isActive ? l10n.tripIsActive : l10n.tripMakeActive),
            ),
            const Divider(height: 24),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.tripDate,
                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                ),
                child: Text(tripDateText(context, _date)),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.tripAutoDeclination),
              subtitle: _autoDeclination ? Text(_autoDeclinationText) : null,
              value: _autoDeclination,
              onChanged: _setAutoDeclination,
            ),
            if (!_autoDeclination)
              TextField(
                controller: _declinationController,
                decoration: InputDecoration(
                  labelText: l10n.tripDeclination,
                  helperText: l10n.tripDeclinationHelp,
                  helperMaxLines: 3,
                  suffixText: _settings.angleUnit.symbol,
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
            const Divider(height: 32),
            Text(l10n.tripReservedSeries,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              l10n.tripReservedSeriesHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            for (final (i, range) in _ranges.indexed)
              _rangeRow(l10n, i, range),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _addRange,
                icon: const Icon(Icons.add),
                label: Text(l10n.tripReservedSeriesAdd),
              ),
            ),
            Text(_nextSeriesText(l10n)),
            if (_misplacedText case final misplaced?) ...[
              const SizedBox(height: 8),
              Text(
                misplaced,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
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

/// The fields of a reserved series range on the trip page
class _RangeFields {
  final TextEditingController first;
  final TextEditingController last;

  _RangeFields(String first, String last)
      : first = TextEditingController(text: first),
        last = TextEditingController(text: last);

  /// Whether both fields are empty, so the range is left out
  bool get isEmpty => first.text.isEmpty && last.text.isEmpty;

  /// The range entered, or null if its first series is missing
  SeriesRange? get range {
    final first = int.tryParse(this.first.text);
    if (first == null) return null;
    return SeriesRange(first, int.tryParse(last.text));
  }

  void dispose() {
    first.dispose();
    last.dispose();
  }
}
