import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/geo_position.dart';
import '../models/settings.dart';

/// Opens the page for [cave] and returns its name as it is when the page is
/// left, or null if it is unchanged or the cave was deleted. See
/// [CavePage.onDelete] and [CavePage.onShowReferencePoints] for the
/// callbacks.
Future<String?> editCave(
  BuildContext context,
  Cave cave, {
  Future<bool> Function()? onDelete,
  VoidCallback? onShowReferencePoints,
}) async {
  final name = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (context) => CavePage(
        cave: cave,
        onDelete: onDelete,
        onShowReferencePoints: onShowReferencePoints,
      ),
    ),
  );
  return name == cave.name ? null : name;
}

/// Page giving an overview of a cave, titled with its name, which it allows
/// to change. Leaving the page pops it with the edited name.
class CavePage extends StatefulWidget {
  final Cave cave;

  /// Deletes the cave and returns whether it was deleted; the page closes
  /// if so. Without it, the page offers no delete button.
  final Future<bool> Function()? onDelete;

  /// Shows the cave's reference points once the page has closed. Offered
  /// when the cave's coordinates are missing or cannot be used.
  final VoidCallback? onShowReferencePoints;

  const CavePage({
    super.key,
    required this.cave,
    this.onDelete,
    this.onShowReferencePoints,
  });

  @override
  State<CavePage> createState() => _CavePageState();
}

class _CavePageState extends State<CavePage> {
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
    _nameController = TextEditingController(text: widget.cave.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// The name as edited; an empty one keeps the cave's own
  String get _name {
    final name = _nameController.text.trim();
    return name.isEmpty ? widget.cave.name : name;
  }

  /// Ends editing the name; an empty one goes back to the cave's own
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
        decoration: InputDecoration(hintText: l10n.explorerCaveName),
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
      tooltip: l10n.caveRename,
      onPressed: () => setState(() => _editingName = true),
    );
  }

  Future<void> _delete() async {
    final deleted = await widget.onDelete!();
    // Closing with no result discards the edits of the deleted cave
    if (deleted && mounted) Navigator.of(context).pop();
  }

  /// A row with [label] and a length in the length unit
  Widget _length(IconData? icon, String label, num meters) {
    final unit = _settings.lengthUnit;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        '${unit.fromMeters(meters).toStringAsFixed(1)} ${unit.symbol}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  /// Closes the page, keeping the edits, and shows the reference points
  void _showReferencePoints() {
    Navigator.of(context).pop(_name);
    widget.onShowReferencePoints!();
  }

  /// The coordinates the automatic declination uses: the cave's first
  /// reference point if it is in Swiss grid coordinates, else the Hölloch's,
  /// with a warning saying why
  List<Widget> _coordinates(AppLocalizations l10n) {
    final ref = widget.cave.firstReferencePoint;
    final usable =
        ref != null && GeoPosition.fromSwissGrid(ref.east, ref.north) != null;
    final heading = ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.place),
      title: Text(usable
          ? l10n.caveCoordinates(ref.id.toString())
          : l10n.caveDefaultCoordinates),
    );
    if (usable) {
      return [
        heading,
        _length(null, l10n.columnEast, ref.east),
        _length(null, l10n.columnNorth, ref.north),
        _length(null, l10n.caveAltitude, ref.altitude),
      ];
    }
    return [
      heading,
      _length(null, l10n.columnEast, GeoPosition.hoellochEast),
      _length(null, l10n.columnNorth, GeoPosition.hoellochNorth),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.warning_amber,
            color: Theme.of(context).colorScheme.error),
        title: Text(ref == null
            ? l10n.caveNoReferencePoint
            : l10n.caveNotSwissGrid(ref.id.toString())),
        trailing: widget.onShowReferencePoints == null
            ? null
            : TextButton(
                onPressed: _showReferencePoints,
                child: Text(l10n.caveShowReferencePoints),
              ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cave = widget.cave;

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
            _length(Icons.straighten, l10n.caveLength, cave.totalLength),
            _length(Icons.height, l10n.caveHeight, cave.heightDifference),
            const Divider(height: 24),
            ..._coordinates(l10n),
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
