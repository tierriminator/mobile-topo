import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/selection_state.dart';
import 'controllers/settings_controller.dart';
import 'data/cave_repository.dart';
import 'data/local_cave_repository.dart';
import 'data/settings_repository.dart';
import 'l10n/app_localizations.dart';
import 'services/bluetooth_adapter.dart';
import 'services/bluetooth_adapter_android.dart';
import 'services/bluetooth_adapter_macos.dart';
import 'services/calibration_service.dart';
import 'services/distox_service.dart';
import 'services/measurement_service.dart';
import 'views/data_view.dart';
import 'views/map_view.dart';
import 'views/sketch_view.dart';
import 'views/explorer_view.dart';
import 'views/options_view.dart';

/// Create the appropriate BluetoothAdapter for the current platform
BluetoothAdapter createBluetoothAdapter() {
  if (Platform.isMacOS) {
    return MacOSBluetoothAdapter();
  } else {
    return AndroidBluetoothAdapter();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load settings before app starts
  final settingsRepository = SettingsRepository();
  final settings = await settingsRepository.load();
  final settingsController = SettingsController(settings);

  // Create platform-specific Bluetooth adapter
  final bluetoothAdapter = createBluetoothAdapter();

  // Create DistoX, Measurement, and Calibration services
  final distoXService = DistoXService(settingsController, bluetoothAdapter);
  final measurementService = MeasurementService(settingsController);
  final calibrationService = CalibrationService(distoXService);
  measurementService.connectDistoX(distoXService);

  // Wire up calibration callbacks
  distoXService.onCalibrationAccel = calibrationService.onCalibrationAccelPacket;
  distoXService.onCalibrationMag = calibrationService.onCalibrationMagPacket;
  distoXService.onMemoryReply = calibrationService.onMemoryReply;

  // Set up callback to save device address on successful connection
  distoXService.onConnectionSuccess = (device) {
    settingsController.setLastConnectedDevice(device.address, device.name);
    settingsRepository.save(settingsController.settings);
  };

  // Attempt auto-connect if enabled
  if (settingsController.autoConnect) {
    distoXService.tryAutoConnect(
      settingsController.lastConnectedDeviceAddress,
      settingsController.lastConnectedDeviceName,
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SelectionState()),
        ChangeNotifierProvider.value(value: settingsController),
        ChangeNotifierProvider.value(value: distoXService),
        ChangeNotifierProvider.value(value: measurementService),
        ChangeNotifierProvider.value(value: calibrationService),
        Provider<CaveRepository>(create: (_) => LocalCaveRepository()),
        Provider<SettingsRepository>(create: (_) => settingsRepository),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 131, 96, 19)),
        useMaterial3: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _views = [
    const DataView(),
    const MapView(),
    const SketchView(),
    const ExplorerView(),
    const OptionsView(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _views,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.table_chart_outlined),
            activeIcon: const Icon(Icons.table_chart),
            label: l10n.dataViewTitle,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            activeIcon: const Icon(Icons.map),
            label: l10n.mapViewTitle,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.draw_outlined),
            activeIcon: const Icon(Icons.draw),
            label: l10n.sketchViewTitle,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.folder_outlined),
            activeIcon: const Icon(Icons.folder),
            label: l10n.explorerViewTitle,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: l10n.optionsViewTitle,
          ),
        ],
      ),
    );
  }
}
