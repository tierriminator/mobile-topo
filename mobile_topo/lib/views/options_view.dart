import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../data/settings_repository.dart';
import '../l10n/app_localizations.dart';
import '../models/settings.dart';
import '../services/distox_service.dart';

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
    final distoX = context.watch<DistoXService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.optionsViewTitle),
      ),
      body: ListView(
        children: [
          // Bluetooth / Device Connection
          _SectionHeader(title: l10n.optionsBluetoothSection),
          _DistoXDeviceTile(distoXService: distoX, l10n: l10n),
          SwitchListTile(
            secondary: const Icon(Icons.autorenew),
            title: Text(l10n.optionsAutoConnect),
            subtitle: Text(l10n.optionsAutoConnectDescription),
            value: distoX.autoReconnect,
            onChanged: (value) {
              distoX.setAutoReconnect(value);
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

/// Widget showing DistoX device connection status with tap to connect/select
class _DistoXDeviceTile extends StatelessWidget {
  final DistoXService distoXService;
  final AppLocalizations l10n;

  const _DistoXDeviceTile({
    required this.distoXService,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final state = distoXService.connectionState;
    final device = distoXService.connectedDevice ?? distoXService.selectedDevice;

    IconData icon;
    Color? iconColor;
    String subtitle;

    switch (state) {
      case DistoXConnectionState.connected:
        icon = Icons.bluetooth_connected;
        iconColor = Colors.green;
        subtitle = device?.name ?? 'Connected';
      case DistoXConnectionState.connecting:
        icon = Icons.bluetooth_searching;
        iconColor = Colors.orange;
        subtitle = 'Connecting...';
      case DistoXConnectionState.reconnecting:
        icon = Icons.bluetooth_searching;
        iconColor = Colors.orange;
        subtitle = 'Reconnecting...';
      case DistoXConnectionState.disconnected:
        icon = Icons.bluetooth;
        iconColor = null;
        subtitle = device?.name ?? l10n.optionsBluetoothDeviceNone;
    }

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(l10n.optionsBluetoothDevice),
      subtitle: Text(subtitle),
      trailing: state == DistoXConnectionState.connected
          ? TextButton(
              onPressed: () => distoXService.disconnect(),
              child: const Text('Disconnect'),
            )
          : const Icon(Icons.chevron_right),
      onTap: state == DistoXConnectionState.connected
          ? null
          : () => _showDeviceSelectionDialog(context),
    );
  }

  Future<void> _showDeviceSelectionDialog(BuildContext context) async {
    final isAvailable = await distoXService.isBluetoothAvailable;
    if (!isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth is not available on this device'),
          ),
        );
      }
      return;
    }

    final isEnabled = await distoXService.isBluetoothEnabled;
    if (!isEnabled) {
      final enabled = await distoXService.requestEnableBluetooth();
      if (!enabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable Bluetooth')),
          );
        }
        return;
      }
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => _DeviceSelectionDialog(
          distoXService: distoXService,
        ),
      );
    }
  }
}

/// Dialog for selecting and connecting to a DistoX device
class _DeviceSelectionDialog extends StatefulWidget {
  final DistoXService distoXService;

  const _DeviceSelectionDialog({required this.distoXService});

  @override
  State<_DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends State<_DeviceSelectionDialog> {
  List<DistoXDevice> _bondedDevices = [];
  final List<DistoXDevice> _discoveredDevices = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  StreamSubscription<DistoXDevice>? _discoverySubscription;

  @override
  void initState() {
    super.initState();
    _loadBondedDevices();
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    widget.distoXService.stopDiscovery();
    super.dispose();
  }

  Future<void> _loadBondedDevices() async {
    final devices = await widget.distoXService.getBondedDevices();
    if (mounted) {
      setState(() => _bondedDevices = devices);
    }
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    _discoverySubscription = widget.distoXService.startDiscovery().listen(
      (device) {
        if (mounted &&
            !_bondedDevices.contains(device) &&
            !_discoveredDevices.contains(device)) {
          setState(() => _discoveredDevices.add(device));
        }
      },
      onDone: () {
        if (mounted) setState(() => _isScanning = false);
      },
    );
  }

  void _stopScanning() {
    _discoverySubscription?.cancel();
    widget.distoXService.stopDiscovery();
    setState(() => _isScanning = false);
  }

  Future<void> _connectToDevice(DistoXDevice device) async {
    setState(() => _isConnecting = true);
    final success = await widget.distoXService.connect(device);
    if (mounted) {
      setState(() => _isConnecting = false);
      if (success) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to connect: ${widget.distoXService.lastError ?? "Unknown error"}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select DistoX Device'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_bondedDevices.isNotEmpty) ...[
              const Text(
                'Paired Devices',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._bondedDevices.map((device) => _DeviceListItem(
                    device: device,
                    onTap: _isConnecting ? null : () => _connectToDevice(device),
                  )),
              const Divider(),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Devices',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_isScanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _discoveredDevices.isEmpty && !_isScanning
                  ? Center(
                      child: Text(
                        _isScanning
                            ? 'Scanning...'
                            : 'Tap Scan to find devices',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    )
                  : ListView(
                      children: _discoveredDevices
                          .map((device) => _DeviceListItem(
                                device: device,
                                onTap: _isConnecting
                                    ? null
                                    : () => _connectToDevice(device),
                              ))
                          .toList(),
                    ),
            ),
            if (_isConnecting)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_isScanning)
          TextButton(
            onPressed: _stopScanning,
            child: const Text('Stop'),
          )
        else
          TextButton(
            onPressed: _isConnecting ? null : _startScanning,
            child: const Text('Scan'),
          ),
      ],
    );
  }
}

/// Single device item in the selection list
class _DeviceListItem extends StatelessWidget {
  final DistoXDevice device;
  final VoidCallback? onTap;

  const _DeviceListItem({
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        device.isBonded ? Icons.bluetooth_connected : Icons.bluetooth,
        color: device.isBonded ? Colors.blue : null,
      ),
      title: Text(device.name),
      subtitle: Text(device.address),
      onTap: onTap,
      dense: true,
    );
  }
}
