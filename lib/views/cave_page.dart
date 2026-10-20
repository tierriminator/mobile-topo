import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/cave.dart';
import '../models/geo_position.dart';
import '../models/settings.dart';

/// What the cave page changes about a cave
typedef CaveEdit = ({String name, GeoPosition? location});

/// Opens the page for [cave] and returns its name and location as they are
/// when the page is left, or null if they are unchanged or the cave was
/// deleted. The page offers deleting the cave if [onDelete] is given; see
/// [CavePage.onDelete].
Future<CaveEdit?> editCave(
  BuildContext context,
  Cave cave, {
  Future<bool> Function()? onDelete,
}) async {
  final edited = await Navigator.of(context).push<CaveEdit>(
    MaterialPageRoute(
      builder: (context) => CavePage(cave: cave, onDelete: onDelete),
    ),
  );
  if (edited == null ||
      (edited.name == cave.name && edited.location == cave.location)) {
    return null;
  }
  return edited;
}

/// Page giving an overview of a cave, titled with its name, to change the
/// name and the location.
/// Leaving the page pops it with the edited name and location.
class CavePage extends StatefulWidget {
  final Cave cave;

  /// Deletes the cave and returns whether it was deleted; the page closes
  /// if so. Without it, the page offers no delete button.
  final Future<bool> Function()? onDelete;

  const CavePage({super.key, required this.cave, this.onDelete});

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
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsController>().settings;
    final location = widget.cave.location;
    _nameController = TextEditingController(text: widget.cave.name);
    _latitudeController =
        TextEditingController(text: location?.latitude.toString() ?? '');
    _longitudeController =
        TextEditingController(text: location?.longitude.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  /// Whether both location fields are empty, which removes the location
  bool get _isLocationEmpty =>
      _latitudeController.text.trim().isEmpty &&
      _longitudeController.text.trim().isEmpty;

  /// The entered location, or null if the fields do not give a valid one
  GeoPosition? get _location {
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (latitude == null || longitude == null) return null;
    final position = GeoPosition(latitude, longitude);
    return position.isValid ? position : null;
  }

  bool get _isLocationInvalid => !_isLocationEmpty && _location == null;

  /// The cave's name and location as edited. An empty name or an invalid
  /// location keeps the cave's own.
  CaveEdit get _edited {
    final name = _nameController.text.trim();
    return (
      name: name.isEmpty ? widget.cave.name : name,
      location: _isLocationEmpty
          ? null
          : _location ?? widget.cave.location,
    );
  }

  /// Ends editing the name; an empty one goes back to the cave's own
  void _finishEditingName() {
    setState(() {
      _editingName = false;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = widget.cave.name;
      }
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
    return Text(_nameController.text.trim());
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

  Widget _figure(IconData icon, String label, double meters) {
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

  Widget _coordinateField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, suffixText: '°'),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
      ],
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cave = widget.cave;

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
            _figure(Icons.straighten, l10n.caveLength, cave.totalLength),
            _figure(Icons.height, l10n.caveHeight, cave.heightDifference),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _coordinateField(
                      _latitudeController, l10n.explorerLatitude),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _coordinateField(
                      _longitudeController, l10n.explorerLongitude),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isLocationInvalid
                  ? l10n.explorerLocationInvalid
                  : l10n.explorerCaveLocationHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _isLocationInvalid
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
