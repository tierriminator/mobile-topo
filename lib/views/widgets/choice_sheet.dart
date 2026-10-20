import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// An option of [showChoiceSheet]
typedef Choice<T> = ({T value, IconData icon, String label, String help});

/// Shows [choices] in a bottom sheet titled [title], each as a row with its
/// icon, label and a line of help, and returns the value of the one tapped,
/// or null if the sheet is dismissed
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<Choice<T>> choices,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(title,
                style: Theme.of(sheetContext).textTheme.titleMedium),
          ),
          for (final choice in choices)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(choice.icon),
              title: Text(choice.label),
              subtitle: Text(choice.help),
              onTap: () => Navigator.of(sheetContext).pop(choice.value),
            ),
        ],
      ),
    ),
  );
}

/// Exports for Therion under [name]: as a survey file, or as the text
/// PocketTopo exports for xtherion if [pocketTopoText] is set
typedef TherionExport = Future<void> Function(String name,
    {required bool pocketTopoText});

/// Asks for the Therion export format: returns whether it is the text
/// PocketTopo exports, or null if the user dismisses the choice
Future<bool?> chooseExportFormat(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showChoiceSheet(context, title: l10n.exportFormat, choices: [
    (
      value: false,
      icon: Icons.description,
      label: l10n.exportTherionSurvey,
      help: l10n.exportTherionSurveyHelp,
    ),
    (
      value: true,
      icon: Icons.draw,
      label: l10n.exportTherionText,
      help: l10n.exportTherionTextHelp,
    ),
  ]);
}
