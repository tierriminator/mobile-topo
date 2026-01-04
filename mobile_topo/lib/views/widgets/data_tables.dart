import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../models/survey.dart';

class StretchesTable extends StatefulWidget {
  final List<MeasuredDistance> data;
  final void Function(int index)? onInsertAbove;
  final void Function(int index)? onInsertBelow;
  final void Function(int index)? onDelete;
  final void Function(int index, MeasuredDistance stretch)? onUpdate;
  final void Function(Point station)? onStartHere;

  const StretchesTable({
    super.key,
    required this.data,
    this.onInsertAbove,
    this.onInsertBelow,
    this.onDelete,
    this.onUpdate,
    this.onStartHere,
  });

  @override
  StretchesTableState createState() => StretchesTableState();
}

class StretchesTableState extends State<StretchesTable> {
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

  void _updateStretch(int index, MeasuredDistance current, {
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

  void _clearEditing() {
    setState(() {
      _editingRow = null;
      _editingCol = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Table(
      border: TableBorder.all(),
      children: [
        TableRow(
          children: [
            TableCell(child: _HeaderCell(text: l10n.columnFrom)),
            TableCell(child: _HeaderCell(text: l10n.columnTo)),
            TableCell(child: _HeaderCell(text: l10n.columnDistance)),
            TableCell(child: _HeaderCell(text: l10n.columnAzimuth)),
            TableCell(child: _HeaderCell(text: l10n.columnInclination)),
          ],
        ),
        for (var i = 0; i < widget.data.length; i++)
          _buildRow(context, i, widget.data[i]),
      ],
    );
  }

  TableRow _buildRow(
    BuildContext context,
    int index,
    MeasuredDistance stretch,
  ) {
    final isSelected = index == _selectedIndex;
    final decoration = isSelected
        ? BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5))
        : null;

    return TableRow(
      decoration: decoration,
      children: [
        _wrapCell(
          context,
          index,
          stretch,
          0,
          _PointCell(
            point: stretch.from,
            isEditing: _editingRow == index && _editingCol == 0,
            onChanged: (p) => _updateStretch(index, stretch, from: p),
            onEditingComplete: _clearEditing,
          ),
        ),
        _wrapCell(
          context,
          index,
          stretch,
          1,
          _PointCell(
            point: stretch.to,
            isEditing: _editingRow == index && _editingCol == 1,
            onChanged: (p) => _updateStretch(index, stretch, to: p),
            onEditingComplete: _clearEditing,
          ),
        ),
        _wrapCell(
          context,
          index,
          stretch,
          2,
          _NumberCell(
            value: stretch.distance,
            decimalPlaces: 2,
            isEditing: _editingRow == index && _editingCol == 2,
            onChanged: (v) => _updateStretch(index, stretch, distance: v),
            onEditingComplete: _clearEditing,
          ),
        ),
        _wrapCell(
          context,
          index,
          stretch,
          3,
          _NumberCell(
            value: stretch.azimut,
            decimalPlaces: 0,
            isEditing: _editingRow == index && _editingCol == 3,
            onChanged: (v) => _updateStretch(index, stretch, azimut: v),
            onEditingComplete: _clearEditing,
          ),
        ),
        _wrapCell(
          context,
          index,
          stretch,
          4,
          _NumberCell(
            value: stretch.inclination,
            signed: true,
            decimalPlaces: 0,
            isEditing: _editingRow == index && _editingCol == 4,
            onChanged: (v) => _updateStretch(index, stretch, inclination: v),
            onEditingComplete: _clearEditing,
          ),
        ),
      ],
    );
  }

  TableCell _wrapCell(
    BuildContext context,
    int row,
    MeasuredDistance stretch,
    int col,
    Widget child,
  ) {
    final l10n = AppLocalizations.of(context)!;
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
              items: [
                PopupMenuItem(
                  value: 'startHere',
                  child: Text(l10n.startHere),
                ),
                PopupMenuItem(
                  value: 'insertAbove',
                  child: Text(l10n.insertAbove),
                ),
                PopupMenuItem(
                  value: 'insertBelow',
                  child: Text(l10n.insertBelow),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.explorerDelete),
                ),
              ],
            ).then((value) {
              debugPrint('Menu selected: $value');
              switch (value) {
                case 'startHere':
                  debugPrint('Calling onStartHere with ${stretch.from}');
                  widget.onStartHere?.call(stretch.from);
                case 'insertAbove':
                  widget.onInsertAbove?.call(row);
                case 'insertBelow':
                  widget.onInsertBelow?.call(row);
                case 'delete':
                  widget.onDelete?.call(row);
              }
            });
          },
          child: child,
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

class ReferencePointsTable extends StatefulWidget {
  final List<ReferencePoint> data;
  final void Function(int index)? onInsertAbove;
  final void Function(int index)? onInsertBelow;
  final void Function(int index)? onDelete;
  final void Function(int index, ReferencePoint point)? onUpdate;

  const ReferencePointsTable({
    super.key,
    required this.data,
    this.onInsertAbove,
    this.onInsertBelow,
    this.onDelete,
    this.onUpdate,
  });

  @override
  ReferencePointsTableState createState() => ReferencePointsTableState();
}

class ReferencePointsTableState extends State<ReferencePointsTable> {
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

  void _updatePoint(int index, ReferencePoint current, {
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

  void _clearEditing() {
    setState(() {
      _editingRow = null;
      _editingCol = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Table(
      border: TableBorder.all(),
      children: [
        TableRow(
          children: [
            TableCell(child: _HeaderCell(text: l10n.columnId)),
            TableCell(child: _HeaderCell(text: l10n.columnEast)),
            TableCell(child: _HeaderCell(text: l10n.columnNorth)),
            TableCell(child: _HeaderCell(text: l10n.columnAltitude)),
          ],
        ),
        for (var i = 0; i < widget.data.length; i++)
          _buildRow(context, i, widget.data[i]),
      ],
    );
  }

  TableRow _buildRow(
    BuildContext context,
    int index,
    ReferencePoint point,
  ) {
    final isSelected = index == _selectedIndex;
    final decoration = isSelected
        ? BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5))
        : null;

    return TableRow(
      decoration: decoration,
      children: [
        _wrapCell(
          context,
          index,
          0,
          _PointCell(
            point: point.id,
            isEditing: _editingRow == index && _editingCol == 0,
            onChanged: (p) => _updatePoint(index, point, id: p),
            onEditingComplete: _clearEditing,
          ),
        ),
        _wrapCell(
          context,
          index,
          1,
          _NumberCell(
            value: point.east,
            signed: true,
            isEditing: _editingRow == index && _editingCol == 1,
            onChanged: (v) => _updatePoint(index, point, east: v),
            onEditingComplete: _clearEditing,
          ),
        ),
        _wrapCell(
          context,
          index,
          2,
          _NumberCell(
            value: point.north,
            signed: true,
            isEditing: _editingRow == index && _editingCol == 2,
            onChanged: (v) => _updatePoint(index, point, north: v),
            onEditingComplete: _clearEditing,
          ),
        ),
        _wrapCell(
          context,
          index,
          3,
          _NumberCell(
            value: point.altitude,
            signed: true,
            isEditing: _editingRow == index && _editingCol == 3,
            onChanged: (v) => _updatePoint(index, point, altitude: v),
            onEditingComplete: _clearEditing,
          ),
        ),
      ],
    );
  }

  TableCell _wrapCell(BuildContext context, int row, int col, Widget child) {
    final l10n = AppLocalizations.of(context)!;
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
              items: [
                PopupMenuItem(
                  value: 'insertAbove',
                  child: Text(l10n.insertAbove),
                ),
                PopupMenuItem(
                  value: 'insertBelow',
                  child: Text(l10n.insertBelow),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.explorerDelete),
                ),
              ],
            ).then((value) {
              switch (value) {
                case 'insertAbove':
                  widget.onInsertAbove?.call(row);
                case 'insertBelow':
                  widget.onInsertBelow?.call(row);
                case 'delete':
                  widget.onDelete?.call(row);
              }
            });
          },
          child: child,
        ),
      ),
    );
  }
}

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

