import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class OptionsView extends StatelessWidget {
  const OptionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
            value: false, // TODO: Get from settings
            onChanged: (value) {
              // TODO: Toggle auto-connect
            },
          ),

          const Divider(),

          // Smart Mode Settings
          _SectionHeader(title: l10n.optionsSmartModeSection),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: Text(l10n.optionsSmartMode),
            subtitle: Text(l10n.optionsSmartModeDescription),
            value: true, // TODO: Get from settings
            onChanged: (value) {
              // TODO: Toggle smart mode
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(l10n.optionsShotDirection),
            subtitle: Text(l10n.optionsShotDirectionForward),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open direction selection dialog
            },
          ),

          const Divider(),

          // Units
          _SectionHeader(title: l10n.optionsUnitsSection),
          ListTile(
            leading: const Icon(Icons.straighten),
            title: Text(l10n.optionsLengthUnit),
            subtitle: Text(l10n.optionsLengthUnitMeters),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open length unit selection
            },
          ),
          ListTile(
            leading: const Icon(Icons.rotate_right),
            title: Text(l10n.optionsAngleUnit),
            subtitle: Text(l10n.optionsAngleUnitDegrees),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open angle unit selection
            },
          ),

          const Divider(),

          // Display Settings
          _SectionHeader(title: l10n.optionsDisplaySection),
          SwitchListTile(
            secondary: const Icon(Icons.grid_on),
            title: Text(l10n.optionsShowGrid),
            subtitle: Text(l10n.optionsShowGridDescription),
            value: true, // TODO: Get from settings
            onChanged: (value) {
              // TODO: Toggle grid display
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
            onTap: () {
              // TODO: Show about dialog
            },
          ),
        ],
      ),
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
