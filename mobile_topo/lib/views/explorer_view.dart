import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/cave_repository.dart';
import '../data/data_service.dart';
import '../l10n/app_localizations.dart';
import '../explorer.dart';

class ExplorerView extends StatefulWidget {
  const ExplorerView({super.key});

  @override
  State<ExplorerView> createState() => _ExplorerViewState();
}

class _ExplorerViewState extends State<ExplorerView> {
  final CaveRepository _repository = DataService().caveRepository;
  final _uuid = const Uuid();

  // Explorer state with loaded caves
  ExplorerState _explorerState = const ExplorerState();

  // Track expanded state for tree nodes
  final Set<String> _expandedIds = {};

  // Loading state
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCaves();
  }

  Future<void> _loadCaves() async {
    setState(() => _isLoading = true);

    final summaries = await _repository.listCaves();
    final caves = <Cave>[];

    for (final summary in summaries) {
      final cave = await _repository.getCave(summary.id);
      if (cave != null) {
        caves.add(cave);
      }
    }

    setState(() {
      _explorerState = ExplorerState(caves: caves);
      _isLoading = false;
    });
  }

  Future<void> _createNewCave() async {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();

    // Show dialog to get cave name
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NewCaveDialog(defaultName: l10n.explorerNewCave),
    );

    if (name == null || name.isEmpty) return;

    final cave = Cave(
      id: _uuid.v4(),
      name: name,
      createdAt: now,
      modifiedAt: now,
    );

    await _repository.saveCave(cave);
    await _loadCaves();

    // Expand the new cave
    setState(() {
      _expandedIds.add(cave.id);
    });
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
                onPressed: _createNewCave,
                tooltip: l10n.explorerAddNew,
              ),
            ],
          ),
        ),
        // Tree view
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _explorerState.caves.isEmpty
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

/// Dialog for creating a new cave
class _NewCaveDialog extends StatefulWidget {
  final String defaultName;

  const _NewCaveDialog({required this.defaultName});

  @override
  State<_NewCaveDialog> createState() => _NewCaveDialogState();
}

class _NewCaveDialogState extends State<_NewCaveDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultName);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.defaultName.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.explorerNewCaveTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.explorerCaveName,
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.create),
        ),
      ],
    );
  }
}
