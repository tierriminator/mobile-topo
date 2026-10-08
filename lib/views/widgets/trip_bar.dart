import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/cave.dart';
import '../trip_page.dart';

/// Thin bar showing the trip new measurements are assigned to. With
/// [warning] set, it stands out to point at a likely wrong trip: one from
/// an earlier day, or none at all.
class TripBar extends StatelessWidget {
  final Cave cave;
  final bool warning;
  final VoidCallback onTap;

  const TripBar({
    super.key,
    required this.cave,
    required this.warning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final trip = cave.activeTrip;
    final background =
        warning ? colors.errorContainer : colors.surfaceContainerHigh;
    final foreground =
        warning ? colors.onErrorContainer : colors.onSurfaceVariant;

    final String text;
    if (trip == null) {
      text = warning ? l10n.tripBarNoTripWarning : l10n.tripBarNoTrip;
    } else {
      final label = tripLabel(context, trip);
      text = warning ? l10n.tripBarOldTrip(label) : '${l10n.trip}: $label';
    }

    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(
                warning ? Icons.warning_amber : Icons.event,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: foreground),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

/// Answers to the trip check
enum TripCheckChoice { keep, newTrip }

/// Asks whether to keep the active trip of [cave], which is from an earlier
/// day or missing, or to start a new one
Future<TripCheckChoice?> showTripCheckDialog(BuildContext context, Cave cave) {
  final l10n = AppLocalizations.of(context)!;
  final trip = cave.activeTrip;

  return showDialog<TripCheckChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(l10n.tripCheckTitle),
      content: Text(
        trip == null
            ? l10n.tripCheckNoTrip
            : l10n.tripCheckOldTrip(tripLabel(context, trip)),
      ),
      // Side by side in equal halves; AlertDialog would stack the buttons
      // once their labels no longer fit next to each other
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pop(TripCheckChoice.keep),
                child: Text(
                  trip == null ? l10n.tripContinueWithout : l10n.tripKeepUsing,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(TripCheckChoice.newTrip),
                child: Text(l10n.tripNew, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
