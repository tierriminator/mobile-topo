import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/settings.dart';

/// Opens the page for [section] of [cave] and returns its name as it is
/// when the page is left, or null if it is unchanged or the section was
/// deleted. See [SectionPage.onSelect] and [SectionPage.onDelete] for the
/// callbacks.
Future<String?> editSection(
  BuildContext context,
  Cave cave,
  Section section, {
  bool isSelected = false,
  VoidCallback? onSelect,
  Future<bool> Function()? onDelete,
}) async {
  final name = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (context) => SectionPage(
        cave: cave,
        section: section,
        isSelected: isSelected,
        onSelect: onSelect,
        onDelete: onDelete,
      ),
    ),
  );
  return name == section.name ? null : name;
}

/// Page giving an overview of a section, titled with its name, which it
/// allows to change, and opening it in the data, map and sketch views.
/// Leaving the page pops it with the name.
class SectionPage extends StatefulWidget {
  /// The cave the section belongs to, whose trips it was measured on
  final Cave cave;
  final Section section;

  /// Whether the section is the one the other views show
  final bool isSelected;

  /// Makes the section the one the other views show once the page has
  /// closed
  final VoidCallback? onSelect;

  /// Deletes the section and returns whether it was deleted; the page
  /// closes if so. Without it, the page offers no delete button.
  final Future<bool> Function()? onDelete;

  const SectionPage({
    super.key,
    required this.cave,
    required this.section,
    this.isSelected = false,
    this.onSelect,
    this.onDelete,
  });

  @override
  State<SectionPage> createState() => _SectionPageState();
}

class _SectionPageState extends State<SectionPage> {
  /// The settings giving the units, which cannot change while the page is
  /// open
  late final Settings _settings;
  late final TextEditingController _nameController;

  /// Whether the title shows a text field to edit the name
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsController>().settings;
    _nameController = TextEditingController(text: widget.section.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// The name as edited; an empty one keeps the section's own
  String get _name {
    final name = _nameController.text.trim();
    return name.isEmpty ? widget.section.name : name;
  }

  /// Ends editing the name; an empty one goes back to the section's own
  void _finishEditingName() {
    setState(() {
      _editingName = false;
      _nameController.text = _name;
    });
  }

  /// The name, or a text field while editing it
  Widget _title(AppLocalizations l10n) {
    if (_editingName) {
      return TextField(
        controller: _nameController,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.explorerSectionName),
        onSubmitted: (_) => _finishEditingName(),
      );
    }
    return Text(_name);
  }

  /// The button starting or ending editing the name, which stays in place
  Widget _nameButton(AppLocalizations l10n) {
    if (_editingName) {
      return IconButton(
        icon: const Icon(Icons.check),
        tooltip: MaterialLocalizations.of(context).okButtonLabel,
        onPressed: _finishEditingName,
      );
    }
    return IconButton(
      icon: const Icon(Icons.edit),
      tooltip: l10n.sectionRename,
      onPressed: () => setState(() => _editingName = true),
    );
  }

  /// Closes the page, keeping the edits, and opens the section
  void _select() {
    Navigator.of(context).pop(_name);
    widget.onSelect!();
  }

  Future<void> _delete() async {
    final deleted = await widget.onDelete!();
    // Closing with no result discards the edits of the deleted section
    if (deleted && mounted) Navigator.of(context).pop();
  }

  /// A row with [label] and [value]
  Widget _figure(IconData icon, String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  /// A length in the length unit
  String _length(num meters) {
    final unit = _settings.lengthUnit;
    return '${unit.fromMeters(meters).toStringAsFixed(1)} ${unit.symbol}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final survey = widget.section.survey;

    return PopScope<String>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_name);
      },
      child: Scaffold(
        appBar: AppBar(title: _title(l10n), actions: [_nameButton(l10n)]),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Shows that the section is open instead once it is
            if (widget.onSelect != null || widget.isSelected) ...[
              FilledButton.tonalIcon(
                onPressed: widget.isSelected ? null : _select,
                icon: Icon(
                    widget.isSelected ? Icons.check : Icons.open_in_new),
                label: Text(widget.isSelected
                    ? l10n.sectionIsSelected
                    : l10n.sectionSelect),
              ),
              const Divider(height: 24),
            ],
            _figure(Icons.straighten, l10n.sectionLength,
                _length(survey.totalLength)),
            _figure(Icons.height, l10n.sectionHeight,
                _length(survey.heightDifference)),
            _figure(Icons.place, l10n.sectionStations,
                '${survey.distinctStations.length}'),
            _figure(Icons.event, l10n.sectionTrips,
                '${widget.cave.tripsUsedBy(widget.section).length}'),
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
