import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../data/settings_repository.dart';
import '../l10n/app_localizations.dart';
import '../models/settings.dart';

class OptionsView extends StatelessWidget {
  const OptionsView({super.key});

  Future<void> _saveSettings(BuildContext context) async {
    final controller = context.read<SettingsController>();
    final repository = context.read<SettingsRepository>();
    await repository.save(controller.settings);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.optionsViewTitle),
      ),
      body: ListView(
        children: [
          // Bluetooth / Device Connection
          _SectionHeader(title: l10n.optionsBluetoothSection),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(l10n.optionsBluetoothDevice),
            subtitle: Text(l10n.optionsBluetoothDeviceNone),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open device selection dialog
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.autorenew),
            title: Text(l10n.optionsAutoConnect),
            subtitle: Text(l10n.optionsAutoConnectDescription),
            value: settings.autoConnect,
            onChanged: (value) {
              settings.autoConnect = value;
              _saveSettings(context);
            },
          ),

          const Divider(),

          // Smart Mode Settings
          _SectionHeader(title: l10n.optionsSmartModeSection),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: Text(l10n.optionsSmartMode),
            subtitle: Text(l10n.optionsSmartModeDescription),
            value: settings.smartModeEnabled,
            onChanged: (value) {
              settings.smartModeEnabled = value;
              _saveSettings(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(l10n.optionsShotDirection),
            subtitle: Text(
              settings.shotDirection == ShotDirection.forward
                  ? l10n.optionsShotDirectionForward
                  : l10n.optionsShotDirectionBackward,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showShotDirectionDialog(context, settings, l10n),
          ),

          const Divider(),

          // Units
          _SectionHeader(title: l10n.optionsUnitsSection),
          ListTile(
            leading: const Icon(Icons.straighten),
            title: Text(l10n.optionsLengthUnit),
            subtitle: Text(
              settings.lengthUnit == LengthUnit.meters
                  ? l10n.optionsLengthUnitMeters
                  : l10n.optionsLengthUnitFeet,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLengthUnitDialog(context, settings, l10n),
          ),
          ListTile(
            leading: const Icon(Icons.rotate_right),
            title: Text(l10n.optionsAngleUnit),
            subtitle: Text(
              settings.angleUnit == AngleUnit.degrees
                  ? l10n.optionsAngleUnitDegrees
                  : l10n.optionsAngleUnitGrad,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAngleUnitDialog(context, settings, l10n),
          ),

          const Divider(),

          // Display Settings
          _SectionHeader(title: l10n.optionsDisplaySection),
          SwitchListTile(
            secondary: const Icon(Icons.grid_on),
            title: Text(l10n.optionsShowGrid),
            subtitle: Text(l10n.optionsShowGridDescription),
            value: settings.showGrid,
            onChanged: (value) {
              settings.showGrid = value;
              _saveSettings(context);
            },
          ),

          const Divider(),

          // Calibration
          _SectionHeader(title: l10n.optionsCalibrationSection),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.optionsCalibration),
            subtitle: Text(l10n.optionsCalibrationDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open calibration screen
            },
          ),

          const Divider(),

          // About
          _SectionHeader(title: l10n.optionsAboutSection),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.optionsAbout),
            subtitle: const Text('Mobile Topo v0.1.0'),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showShotDirectionDialog(
    BuildContext context,
    SettingsController settings,
    AppLocalizations l10n,
  ) async {
    final repository = context.read<SettingsRepository>();
    final value = await showDialog<ShotDirection>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.optionsShotDirection),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ShotDirection.forward),
            child: ListTile(
              leading: Icon(
                settings.shotDirection == ShotDirection.forward
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(l10n.optionsShotDirectionForward),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ShotDirection.backward),
            child: ListTile(
              leading: Icon(
                settings.shotDirection == ShotDirection.backward
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(l10n.optionsShotDirectionBackward),
            ),
          ),
        ],
      ),
    );
    if (value != null) {
      settings.shotDirection = value;
      await repository.save(settings.settings);
    }
  }

  void _showLengthUnitDialog(
    BuildContext context,
    SettingsController settings,
    AppLocalizations l10n,
  ) async {
    final repository = context.read<SettingsRepository>();
    final value = await showDialog<LengthUnit>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.optionsLengthUnit),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, LengthUnit.meters),
            child: ListTile(
              leading: Icon(
                settings.lengthUnit == LengthUnit.meters
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(l10n.optionsLengthUnitMeters),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, LengthUnit.feet),
            child: ListTile(
              leading: Icon(
                settings.lengthUnit == LengthUnit.feet
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(l10n.optionsLengthUnitFeet),
            ),
          ),
        ],
      ),
    );
    if (value != null) {
      settings.lengthUnit = value;
      await repository.save(settings.settings);
    }
  }

  void _showAngleUnitDialog(
    BuildContext context,
    SettingsController settings,
    AppLocalizations l10n,
  ) async {
    final repository = context.read<SettingsRepository>();
    final value = await showDialog<AngleUnit>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.optionsAngleUnit),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, AngleUnit.degrees),
            child: ListTile(
              leading: Icon(
                settings.angleUnit == AngleUnit.degrees
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(l10n.optionsAngleUnitDegrees),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, AngleUnit.grad),
            child: ListTile(
              leading: Icon(
                settings.angleUnit == AngleUnit.grad
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(l10n.optionsAngleUnitGrad),
            ),
          ),
        ],
      ),
    );
    if (value != null) {
      settings.angleUnit = value;
      await repository.save(settings.settings);
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Mobile Topo',
      applicationVersion: '0.1.0',
      applicationLegalese: 'Cave surveying app inspired by PocketTopo',
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
