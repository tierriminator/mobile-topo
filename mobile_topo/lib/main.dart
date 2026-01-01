import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'views/data_view.dart';
import 'views/map_view.dart';
import 'views/sketch_view.dart';
import 'views/files_view.dart';
import 'views/options_view.dart';

void main() {
  runApp(const MyApp());
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
    const FilesView(),
    const OptionsView(),
  ];

  String _getTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_selectedIndex) {
      case 0:
        return l10n.dataViewTitle;
      case 1:
        return l10n.mapViewTitle;
      case 2:
        return l10n.sketchViewTitle;
      case 3:
        return l10n.filesViewTitle;
      case 4:
        return l10n.optionsViewTitle;
      default:
        return '';
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_getTitle(context)),
      ),
      body: _views[_selectedIndex],
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
            label: l10n.filesViewTitle,
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
