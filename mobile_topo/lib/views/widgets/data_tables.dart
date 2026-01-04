import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../models/survey.dart';

/// Base class for editable data tables with sticky headers.
abstract class EditableDataTable<T> extends StatefulWidget {
  final List<T> data;
  final void Function(int index)? onInsertAbove;
  final void Function(int index)? onInsertBelow;
  final void Function(int index)? onDelete;
  final VoidCallback? onAdd;

  const EditableDataTable({
    super.key,
    required this.data,
    this.onInsertAbove,
    this.onInsertBelow,
    this.onDelete,
    this.onAdd,
  });
}

/// Base state class for editable data tables.
abstract class EditableDataTableState<T, W extends EditableDataTable<T>>
    extends State<W> {
  int? _selectedIndex;
  int? _editingRow;
  int? _editingCol;

  void clearSelection() {
    setState(() {
      _selectedIndex = null;
      _editingRow = null;
      _editingCol = null;
    });
  }

  void _clearEditing() {
    setState(() {
      _editingRow = null;
      _editingCol = null;
    });
  }

  /// Build the header cells for this table.
  List<Widget> buildHeaderCells(AppLocalizations l10n);

  /// Build a data row for the given index and item.
  List<Widget> buildDataCells(int index, T item);

  /// Build context menu items for the given row.
  List<PopupMenuEntry<String>> buildContextMenuItems(
      AppLocalizations l10n, int index, T item);

  /// Handle context menu selection.
  void handleContextMenuSelection(String? value, int index, T item);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final headerCells = buildHeaderCells(l10n);

    return Column(
      children: [
        // Sticky header
        Table(
          border: const TableBorder(
            verticalInside: BorderSide(),
          ),
          children: [
            TableRow(
              children: headerCells
                  .map((cell) => TableCell(child: cell))
                  .toList(),
            ),
          ],
        ),
        const Divider(height: 1, thickness: 1),
        // Scrollable data rows
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Table(
                  border: const TableBorder(
                    verticalInside: BorderSide(),
                    horizontalInside: BorderSide(),
                  ),
                  children: [
                    for (var i = 0; i < widget.data.length; i++)
                      _buildRow(context, l10n, i, widget.data[i]),
                  ],
                ),
                // Add row button
                if (widget.onAdd != null)
                  _buildAddRow(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddRow(BuildContext context) {
    return InkWell(
      onTap: widget.onAdd,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: widget.data.isEmpty
                ? BorderSide.none
                : const BorderSide(),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Icon(
            Icons.add,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  TableRow _buildRow(
    BuildContext context,
    AppLocalizations l10n,
    int index,
    T item,
  ) {
    final isSelected = index == _selectedIndex;
    final decoration = isSelected
        ? BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.5))
        : null;

    final cells = buildDataCells(index, item);

    return TableRow(
      decoration: decoration,
      children: [
        for (var col = 0; col < cells.length; col++)
          _wrapCell(context, l10n, index, col, item, cells[col]),
      ],
    );
  }

  TableCell _wrapCell(
    BuildContext context,
    AppLocalizations l10n,
    int row,
    int col,
    T item,
    Widget child,
  ) {
    return TableCell(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          setState(() {
            _selectedIndex = _selectedIndex == row ? null : row;
          });
        },
        child: GestureDetector(
          onDoubleTap: () {
            setState(() {
              _editingRow = row;
              _editingCol = col;
            });
          },
          onLongPressStart: (details) {
            showMenu(
              context: context,
              position: RelativeRect.fromLTRB(
                details.globalPosition.dx,
                details.globalPosition.dy,
                details.globalPosition.dx,
                details.globalPosition.dy,
              ),
              items: buildContextMenuItems(l10n, row, item),
            ).then((value) => handleContextMenuSelection(value, row, item));
          },
          child: child,
        ),
      ),
    );
  }

  bool isEditing(int row, int col) => _editingRow == row && _editingCol == col;
}

// =============================================================================
// StretchesTable
// =============================================================================

class StretchesTable extends EditableDataTable<MeasuredDistance> {
  final void Function(int index, MeasuredDistance stretch)? onUpdate;
  final void Function(Point station)? onStartHere;
  final void Function(num corridorId)? onContinueHere;

  const StretchesTable({
    super.key,
    required super.data,
    super.onInsertAbove,
    super.onInsertBelow,
    super.onDelete,
    super.onAdd,
    this.onUpdate,
    this.onStartHere,
    this.onContinueHere,
  });

  @override
  StretchesTableState createState() => StretchesTableState();
}

class StretchesTableState
    extends EditableDataTableState<MeasuredDistance, StretchesTable> {
  void _updateStretch(
    int index,
    MeasuredDistance current, {
    Point? from,
    Point? to,
    num? distance,
    num? azimut,
    num? inclination,
  }) {
    final updated = MeasuredDistance(
      from ?? current.from,
      to ?? current.to,
      distance ?? current.distance,
      azimut ?? current.azimut,
      inclination ?? current.inclination,
    );
    widget.onUpdate?.call(index, updated);
  }

  @override
  List<Widget> buildHeaderCells(AppLocalizations l10n) {
    return [
      _HeaderCell(text: l10n.columnFrom),
      _HeaderCell(text: l10n.columnTo),
      _HeaderCell(text: l10n.columnDistance),
      _HeaderCell(text: l10n.columnAzimuth),
      _HeaderCell(text: l10n.columnInclination),
    ];
  }

  @override
  List<Widget> buildDataCells(int index, MeasuredDistance stretch) {
    return [
      _PointCell(
        point: stretch.from,
        isEditing: isEditing(index, 0),
        onChanged: (p) => _updateStretch(index, stretch, from: p),
        onEditingComplete: _clearEditing,
      ),
      _PointCell(
        point: stretch.to,
        isEditing: isEditing(index, 1),
        onChanged: (p) => _updateStretch(index, stretch, to: p),
        onEditingComplete: _clearEditing,
      ),
      _NumberCell(
        value: stretch.distance,
        decimalPlaces: 2,
        isEditing: isEditing(index, 2),
        onChanged: (v) => _updateStretch(index, stretch, distance: v),
        onEditingComplete: _clearEditing,
      ),
      _NumberCell(
        value: stretch.azimut,
        decimalPlaces: 0,
        isEditing: isEditing(index, 3),
        onChanged: (v) => _updateStretch(index, stretch, azimut: v),
        onEditingComplete: _clearEditing,
      ),
      _NumberCell(
        value: stretch.inclination,
        signed: true,
        decimalPlaces: 0,
        isEditing: isEditing(index, 4),
        onChanged: (v) => _updateStretch(index, stretch, inclination: v),
        onEditingComplete: _clearEditing,
      ),
    ];
  }

  @override
  List<PopupMenuEntry<String>> buildContextMenuItems(
      AppLocalizations l10n, int index, MeasuredDistance item) {
    return [
      PopupMenuItem(value: 'startHere', child: Text(l10n.startHere)),
      PopupMenuItem(value: 'continueHere', child: Text(l10n.continueHere)),
      PopupMenuItem(value: 'insertAbove', child: Text(l10n.insertAbove)),
      PopupMenuItem(value: 'insertBelow', child: Text(l10n.insertBelow)),
      PopupMenuItem(value: 'delete', child: Text(l10n.explorerDelete)),
    ];
  }

  @override
  void handleContextMenuSelection(
      String? value, int index, MeasuredDistance item) {
    switch (value) {
      case 'startHere':
        widget.onStartHere?.call(item.from);
      case 'continueHere':
        widget.onContinueHere?.call(item.from.corridorId);
      case 'insertAbove':
        widget.onInsertAbove?.call(index);
      case 'insertBelow':
        widget.onInsertBelow?.call(index);
      case 'delete':
        widget.onDelete?.call(index);
    }
  }
}

// =============================================================================
// ReferencePointsTable
// =============================================================================

class ReferencePointsTable extends EditableDataTable<ReferencePoint> {
  final void Function(int index, ReferencePoint point)? onUpdate;

  const ReferencePointsTable({
    super.key,
    required super.data,
    super.onInsertAbove,
    super.onInsertBelow,
    super.onDelete,
    super.onAdd,
    this.onUpdate,
  });

  @override
  ReferencePointsTableState createState() => ReferencePointsTableState();
}

class ReferencePointsTableState
    extends EditableDataTableState<ReferencePoint, ReferencePointsTable> {
  void _updatePoint(
    int index,
    ReferencePoint current, {
    Point? id,
    num? east,
    num? north,
    num? altitude,
  }) {
    final updated = ReferencePoint(
      id ?? current.id,
      east ?? current.east,
      north ?? current.north,
      altitude ?? current.altitude,
    );
    widget.onUpdate?.call(index, updated);
  }

  @override
  List<Widget> buildHeaderCells(AppLocalizations l10n) {
    return [
      _HeaderCell(text: l10n.columnId),
      _HeaderCell(text: l10n.columnEast),
      _HeaderCell(text: l10n.columnNorth),
      _HeaderCell(text: l10n.columnAltitude),
    ];
  }

  @override
  List<Widget> buildDataCells(int index, ReferencePoint point) {
    return [
      _PointCell(
        point: point.id,
        isEditing: isEditing(index, 0),
        onChanged: (p) => _updatePoint(index, point, id: p),
        onEditingComplete: _clearEditing,
      ),
      _NumberCell(
        value: point.east,
        signed: true,
        isEditing: isEditing(index, 1),
        onChanged: (v) => _updatePoint(index, point, east: v),
        onEditingComplete: _clearEditing,
      ),
      _NumberCell(
        value: point.north,
        signed: true,
        isEditing: isEditing(index, 2),
        onChanged: (v) => _updatePoint(index, point, north: v),
        onEditingComplete: _clearEditing,
      ),
      _NumberCell(
        value: point.altitude,
        signed: true,
        isEditing: isEditing(index, 3),
        onChanged: (v) => _updatePoint(index, point, altitude: v),
        onEditingComplete: _clearEditing,
      ),
    ];
  }

  @override
  List<PopupMenuEntry<String>> buildContextMenuItems(
      AppLocalizations l10n, int index, ReferencePoint item) {
    return [
      PopupMenuItem(value: 'insertAbove', child: Text(l10n.insertAbove)),
      PopupMenuItem(value: 'insertBelow', child: Text(l10n.insertBelow)),
      PopupMenuItem(value: 'delete', child: Text(l10n.explorerDelete)),
    ];
  }

  @override
  void handleContextMenuSelection(
      String? value, int index, ReferencePoint item) {
    switch (value) {
      case 'insertAbove':
        widget.onInsertAbove?.call(index);
      case 'insertBelow':
        widget.onInsertBelow?.call(index);
      case 'delete':
        widget.onDelete?.call(index);
    }
  }
}

// =============================================================================
// Cell Widgets
// =============================================================================

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _PointCell extends StatefulWidget {
  final Point? point;
  final bool isEditing;
  final void Function(Point?)? onChanged;
  final VoidCallback? onEditingComplete;

  const _PointCell({
    required this.point,
    this.isEditing = false,
    this.onChanged,
    this.onEditingComplete,
  });

  @override
  State<_PointCell> createState() => _PointCellState();
}

class _PointCellState extends State<_PointCell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  String _pointToString(Point? point) => point?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _pointToString(widget.point));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_PointCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point != widget.point && !_focusNode.hasFocus) {
      _controller.text = _pointToString(widget.point);
    }
    if (widget.isEditing && !oldWidget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _saveValue();
      widget.onEditingComplete?.call();
    }
  }

  void _saveValue() {
    final value = _controller.text.trim();
    // Empty input means no destination (splay shot)
    if (value.isEmpty) {
      widget.onChanged?.call(null);
      return;
    }
    final parts = value.split('.');
    if (parts.length == 2) {
      final corridor = num.tryParse(parts[0]);
      final point = num.tryParse(parts[1]);
      if (corridor != null && point != null) {
        widget.onChanged?.call(Point(corridor, point));
        return;
      }
    }
    _controller.text = _pointToString(widget.point);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          _pointToString(widget.point),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: Theme.of(context).textTheme.bodySmall,
          decoration: const InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _focusNode.unfocus(),
        ),
      ),
    );
  }
}

class _NumberCell extends StatefulWidget {
  final num value;
  final bool signed;
  final int? decimalPlaces;
  final bool isEditing;
  final void Function(num)? onChanged;
  final VoidCallback? onEditingComplete;

  const _NumberCell({
    required this.value,
    this.signed = false,
    this.decimalPlaces,
    this.isEditing = false,
    this.onChanged,
    this.onEditingComplete,
  });

  @override
  State<_NumberCell> createState() => _NumberCellState();
}

class _NumberCellState extends State<_NumberCell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_NumberCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = _formatValue(widget.value);
    }
    if (widget.isEditing && !oldWidget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      });
    }
  }

  String _formatValue(num value) {
    final decimals = widget.decimalPlaces;
    if (decimals != null) {
      return value.toDouble().toStringAsFixed(decimals);
    }
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _saveValue();
      widget.onEditingComplete?.call();
    }
  }

  void _saveValue() {
    final parsed = num.tryParse(_controller.text);
    if (parsed != null) {
      widget.onChanged?.call(parsed);
    } else {
      _controller.text = _formatValue(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          _formatValue(widget.value),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: Theme.of(context).textTheme.bodySmall,
          decoration: const InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
          ),
          keyboardType: TextInputType.numberWithOptions(
            decimal: true,
            signed: widget.signed,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              widget.signed ? RegExp(r'^-?\d*\.?\d*') : RegExp(r'^\d*\.?\d*'),
            ),
          ],
          onSubmitted: (_) => _focusNode.unfocus(),
        ),
      ),
    );
  }
}
