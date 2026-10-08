import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/selection_state.dart';
import 'controllers/settings_controller.dart';
import 'data/cave_repository.dart';
import 'data/local_cave_repository.dart';
import 'data/settings_repository.dart';
import 'l10n/app_localizations.dart';
import 'models/cave.dart';
import 'services/bluetooth_adapter.dart';
import 'services/bluetooth_adapter_android.dart';
import 'services/bluetooth_adapter_macos.dart';
import 'services/calibration_service.dart';
import 'services/distox_service.dart';
import 'services/measurement_service.dart';
import 'services/screen_density.dart';
import 'views/data_view.dart';
import 'views/map_view.dart';
import 'views/sketch_view.dart';
import 'views/explorer_view.dart';
import 'views/options_view.dart';
import 'views/widgets/trip_bar.dart';

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

  // Physical size of logical pixels, for true map scales
  final screenDensity = await ScreenDensity.load();

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
        Provider<ScreenDensity>.value(value: screenDensity),
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
  static const _explorerIndex = 3;

  int _selectedIndex = 0;

  final _explorerKey = GlobalKey<ExplorerViewState>();

  late final List<Widget> _views = [
    const DataView(),
    const MapView(),
    const SketchView(),
    ExplorerView(key: _explorerKey),
    const OptionsView(),
  ];

  late final SelectionState _selectionState;
  late final DistoXService _distoXService;
  bool _wasConnected = false;

  /// Set when the DistoX connects, until the trip of the selected cave has
  /// been checked; the selection may still be loading at that point
  bool _tripCheckPending = false;

  /// Trips confirmed with "Keep trip" (or caves confirmed with "Continue" to
  /// go on without a trip), see [_tripKey]. Kept until the app restarts.
  final Set<String> _keptTrips = {};

  /// Whether the trip check dialog is showing, so reconnects don't stack it
  bool _tripCheckOpen = false;

  @override
  void initState() {
    super.initState();
    _selectionState = context.read<SelectionState>()
      ..addListener(_runPendingTripCheck);
    _distoXService = context.read<DistoXService>()
      ..addListener(_onConnectionChanged);
    // Auto-connect starts before the app is shown and may already be done
    _onConnectionChanged();
  }

  @override
  void dispose() {
    _selectionState.removeListener(_runPendingTripCheck);
    _distoXService.removeListener(_onConnectionChanged);
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Identifies the active trip of a cave, or its lack of one
  String _tripKey(Cave cave) => '${cave.id}/${cave.activeTrip?.id ?? ''}';

  /// Whether the active trip of [cave] is likely wrong, being from an
  /// earlier day or missing, and that has not been accepted
  bool _needsTripCheck(Cave cave) {
    final trip = cave.activeTrip;
    final suspicious = trip == null || trip.isFromDayBefore(DateTime.now());
    return suspicious && !_keptTrips.contains(_tripKey(cave));
  }

  /// Checks the trip each time the DistoX connects, as that is when a
  /// survey starts
  void _onConnectionChanged() {
    final connected = _distoXService.isConnected;
    if (connected && !_wasConnected) {
      _tripCheckPending = true;
      _runPendingTripCheck();
    }
    _wasConnected = connected;
  }

  void _runPendingTripCheck() {
    final cave = _selectionState.selectedCave;    if (!_tripCheckPending || cave == null) return;
    _tripCheckPending = false;
    if (_needsTripCheck(cave)) _checkTrip(cave);
  }

  Future<void> _checkTrip(Cave cave) async {
    if (_tripCheckOpen) return;
    _tripCheckOpen = true;
    // The check may be triggered while building, e.g. from initState, where
    // no dialog can be opened yet
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final choice = await showTripCheckDialog(context, cave);
    _tripCheckOpen = false;
    if (!mounted) return;
    switch (choice) {
      case TripCheckChoice.keep:
        setState(() => _keptTrips.add(_tripKey(cave)));
      case TripCheckChoice.newTrip:
        await _newTrip(cave);
      case null:
        break;
    }
  }

  /// Creates a trip in the explorer and opens it there
  Future<void> _newTrip(Cave cave) async {
    setState(() => _selectedIndex = _explorerIndex);
    await _explorerKey.currentState?.createTrip(cave.id);
  }

  void _onTripBarTapped(Cave cave) {
    if (cave.activeTrip == null) {
      _newTrip(cave);
    } else {
      _checkTrip(cave);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cave = context.watch<SelectionState>().selectedCave;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _views,
            ),
          ),
          // Shown on every tab while the trip looks wrong, so that is noticed
          // before measuring
          if (cave != null && _needsTripCheck(cave))
            TripBar(
              cave: cave,
              onTap: () => _onTripBarTapped(cave),
            ),
        ],
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
