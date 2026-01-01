import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../explorer.dart';
import '../topo.dart';

class ExplorerView extends StatefulWidget {
  const ExplorerView({super.key});

  @override
  State<ExplorerView> createState() => _ExplorerViewState();
}

class _ExplorerViewState extends State<ExplorerView> {
  // Placeholder data - will be replaced with actual state management
  late ExplorerState _explorerState;

  // Track expanded state for tree nodes
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _explorerState = _createSampleData();
  }

  ExplorerState _createSampleData() {
    final now = DateTime.now();

    // Create sample sections
    final section1 = Section(
      id: 'section-1',
      name: 'Entrance',
      survey: const Survey(
        stretches: [
          MeasuredDistance(Point(1, 0), Point(1, 1), 5.0, 45.0, -10.0),
          MeasuredDistance(Point(1, 1), Point(1, 2), 4.0, 90.0, 5.0),
        ],
        referencePoints: [
          ReferencePoint(Point(1, 0), 0.0, 0.0, 100.0),
        ],
      ),
      createdAt: now,
      modifiedAt: now,
    );

    final section2 = Section(
      id: 'section-2',
      name: 'Main Gallery',
      survey: const Survey(
        stretches: [
          MeasuredDistance(Point(1, 2), Point(1, 3), 6.0, 120.0, -5.0),
          MeasuredDistance(Point(1, 3), Point(1, 4), 3.5, 180.0, 0.0),
        ],
        referencePoints: [],
      ),
      createdAt: now,
      modifiedAt: now,
    );

    final section3 = Section(
      id: 'section-3',
      name: 'Side Passage',
      survey: const Survey(
        stretches: [
          MeasuredDistance(Point(2, 0), Point(2, 1), 5.5, 60.0, -10.0),
        ],
        referencePoints: [],
      ),
      createdAt: now,
      modifiedAt: now,
    );

    // Create sample areas
    final upperLevel = Area(
      id: 'area-upper',
      name: 'Upper Level',
      sections: [section2],
      createdAt: now,
      modifiedAt: now,
    );

    final lowerLevel = Area(
      id: 'area-lower',
      name: 'Lower Level',
      sections: [section3],
      createdAt: now,
      modifiedAt: now,
    );

    // Create sample cave
    final cave = Cave(
      id: 'cave-1',
      name: 'Sample Cave',
      description: 'A sample cave for testing',
      sections: [section1],
      areas: [upperLevel, lowerLevel],
      createdAt: now,
      modifiedAt: now,
    );

    return ExplorerState(caves: [cave]);
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  void _selectSection(ExplorerPath path) {
    setState(() {
      _explorerState = _explorerState.copyWith(currentPath: path);
    });
    // TODO: Navigate to the section data/sketch view
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Toolbar
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text(
                l10n.explorerTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  // TODO: Add new cave/area/section
                },
                tooltip: l10n.explorerAddNew,
              ),
            ],
          ),
        ),
        // Tree view
        Expanded(
          child: _explorerState.caves.isEmpty
              ? Center(child: Text(l10n.explorerEmpty))
              : ListView(
                  children: [
                    for (final cave in _explorerState.caves)
                      _buildCaveNode(cave),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCaveNode(Cave cave) {
    final isExpanded = _expandedIds.contains(cave.id);
    final hasChildren = cave.areas.isNotEmpty || cave.sections.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTreeTile(
          icon: Icons.landscape,
          iconColor: Colors.brown,
          label: cave.name,
          subtitle: cave.description,
          depth: 0,
          isExpanded: isExpanded,
          hasChildren: hasChildren,
          onTap: hasChildren ? () => _toggleExpanded(cave.id) : null,
        ),
        if (isExpanded) ...[
          for (final area in cave.areas)
            _buildAreaNode(area, ExplorerPath.cave(cave.id), 1),
          for (final section in cave.sections)
            _buildSectionNode(section, ExplorerPath.cave(cave.id), 1),
        ],
      ],
    );
  }

  Widget _buildAreaNode(Area area, ExplorerPath parentPath, int depth) {
    final isExpanded = _expandedIds.contains(area.id);
    final hasChildren = area.subAreas.isNotEmpty || area.sections.isNotEmpty;
    final currentPath = parentPath.enterArea(area.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTreeTile(
          icon: Icons.folder,
          iconColor: Colors.amber.shade700,
          label: area.name,
          depth: depth,
          isExpanded: isExpanded,
          hasChildren: hasChildren,
          onTap: hasChildren ? () => _toggleExpanded(area.id) : null,
        ),
        if (isExpanded) ...[
          for (final subArea in area.subAreas)
            _buildAreaNode(subArea, currentPath, depth + 1),
          for (final section in area.sections)
            _buildSectionNode(section, currentPath, depth + 1),
        ],
      ],
    );
  }

  Widget _buildSectionNode(Section section, ExplorerPath parentPath, int depth) {
    final path = parentPath.toSection(section.id);
    final isSelected = _explorerState.currentPath?.sectionId == section.id;

    return _buildTreeTile(
      icon: Icons.description,
      iconColor: Colors.blue,
      label: section.name,
      depth: depth,
      isExpanded: false,
      hasChildren: false,
      isSelected: isSelected,
      onTap: () => _selectSection(path),
    );
  }

  Widget _buildTreeTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? subtitle,
    required int depth,
    required bool isExpanded,
    required bool hasChildren,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        padding: EdgeInsets.only(
          left: 16.0 + depth * 24.0,
          right: 16.0,
          top: 8.0,
          bottom: 8.0,
        ),
        child: Row(
          children: [
            if (hasChildren)
              Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            else
              const SizedBox(width: 20),
            const SizedBox(width: 4),
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
