import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/coordinate_system.dart';
import '../models/geo_position.dart';
import '../models/settings.dart';
import 'widgets/choice_sheet.dart';
import 'widgets/coordinate_system_field.dart';

/// What the cave page changes about a cave
typedef CaveEdit = ({String name, CoordinateSystem coordinateSystem});

/// Opens the page for [cave] and returns its name and coordinate system as
/// they are when the page is left, or null if they are unchanged or the
/// cave was deleted. The page starts editing the name if [editName] is set.
/// See [CavePage.onExport], [CavePage.onDelete] and
/// [CavePage.onShowReferencePoints] for the callbacks.
Future<CaveEdit?> editCave(
  BuildContext context,
  Cave cave, {
  bool editName = false,
  TherionExport? onExport,
  Future<bool> Function()? onDelete,
  VoidCallback? onShowReferencePoints,
}) async {
  final edited = await Navigator.of(context).push<CaveEdit>(
    MaterialPageRoute(
      builder: (context) => CavePage(
        cave: cave,
        editName: editName,
        onExport: onExport,
        onDelete: onDelete,
        onShowReferencePoints: onShowReferencePoints,
      ),
    ),
  );
  if (edited == null ||
      (edited.name == cave.name &&
          edited.coordinateSystem == cave.coordinateSystem)) {
    return null;
  }
  return edited;
}

/// Page giving an overview of a cave, titled with its name, which it allows
/// to change along with the coordinate system. Leaving the page pops it
/// with the edits.
class CavePage extends StatefulWidget {
  final Cave cave;

  /// Whether the page starts editing the name, all of it selected, as for
  /// a new cave
  final bool editName;

  /// Exports the cave under its name as edited. Without it, the page offers
  /// no export button.
  final TherionExport? onExport;

  /// Deletes the cave and returns whether it was deleted; the page closes
  /// if so. Without it, the page offers no delete button.
  final Future<bool> Function()? onDelete;

  /// Shows the cave's reference points once the page has closed. Offered
  /// when the cave's coordinates are missing or cannot be used.
  final VoidCallback? onShowReferencePoints;

  const CavePage({
    super.key,
    required this.cave,
    this.editName = false,
    this.onExport,
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
  late bool _editingName = widget.editName;
  late CoordinateSystem _coordinateSystem;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsController>().settings;
    _nameController = TextEditingController(text: widget.cave.name);
    _nameController.selection = TextSelection(
        baseOffset: 0, extentOffset: widget.cave.name.length);
    _coordinateSystem = widget.cave.coordinateSystem;
  }

  CaveEdit get _edited => (name: _name, coordinateSystem: _coordinateSystem);

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

  /// Asks for the format and exports the cave under the edited name
  Future<void> _export() async {
    final pocketTopoText = await chooseExportFormat(context);
    if (pocketTopoText == null) return;
    await widget.onExport!(_name, pocketTopoText: pocketTopoText);
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

  /// A row with [label] and an angle in degrees
  Widget _degrees(String label, num degrees) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(null),
      title: Text(label),
      trailing: Text(
        '${degrees.toStringAsFixed(6)}°',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  /// Closes the page, keeping the edits, and shows the reference points
  void _showReferencePoints() {
    Navigator.of(context).pop(_edited);
    widget.onShowReferencePoints!();
  }

  /// Choice of the coordinate system; UTM starts in the cave's zone
  List<Widget> _coordinateSystemChoice(Cave cave) => [
        CoordinateSystemField(
          value: _coordinateSystem,
          utmStart: Utm.containing(cave.declinationPosition),
          onChanged: (system) => setState(() => _coordinateSystem = system),
        ),
        const SizedBox(height: 8),
      ];

  /// A row with [label] and a coordinate in metres
  Widget _metres(String label, num metres) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(null),
      title: Text(label),
      trailing: Text(
        '${metres.toStringAsFixed(1)} m',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  /// East and North in the unit of the cave's coordinate system: metres or
  /// degrees
  List<Widget> _eastNorth(AppLocalizations l10n, num east, num north) {
    if (_coordinateSystem.isMetric) {
      return [
        _metres(l10n.columnEast, east),
        _metres(l10n.columnNorth, north),
      ];
    }
    return [
      _degrees(l10n.caveLongitude, east),
      _degrees(l10n.caveLatitude, north),
    ];
  }

  /// The coordinates the automatic declination uses, in the coordinate
  /// system: the cave's first reference point if it has a position, else
  /// the Hölloch's, with a warning saying why
  List<Widget> _coordinates(AppLocalizations l10n, Cave cave) {
    final first = cave.firstReferencePoint;
    final ref = first == null ? null : cave.inCoordinateSystem(first);
    final usable = ref != null && cave.referencePosition != null;
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
        ..._eastNorth(l10n, ref.east, ref.north),
        _length(null, l10n.caveAltitude, ref.altitude),
      ];
    }
    final hoelloch = _coordinateSystem.fromGeo(GeoPosition.hoelloch);
    return [
      heading,
      ..._eastNorth(l10n, hoelloch.east, hoelloch.north),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.warning_amber,
            color: Theme.of(context).colorScheme.error),
        title: Text(ref == null
            ? l10n.caveNoReferencePoint
            : l10n.caveNotInCoordinateSystem(ref.id.toString())),
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
    // Positions and coordinates depend on the coordinate system as edited
    final cave = widget.cave.copyWith(coordinateSystem: _coordinateSystem);

    return PopScope<CaveEdit>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_edited);
      },
      child: Scaffold(
        appBar: AppBar(title: _title(l10n), actions: [_nameButton(l10n)]),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _length(Icons.straighten, l10n.caveLength, cave.totalLength),
            _length(Icons.height, l10n.caveHeight, cave.heightDifference),
            const Divider(height: 24),
            ..._coordinateSystemChoice(cave),
            ..._coordinates(l10n, cave),
            if (widget.onExport != null || widget.onDelete != null)
              const Divider(height: 24),
            if (widget.onExport != null)
              OutlinedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.save_alt),
                label: Text(l10n.exportAction),
              ),
            if (widget.onExport != null && widget.onDelete != null)
              const SizedBox(height: 8),
            if (widget.onDelete != null)
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
        ),
      ),
    );
  }
}
