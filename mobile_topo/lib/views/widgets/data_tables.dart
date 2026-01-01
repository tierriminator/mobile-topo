import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../models/survey.dart';

class StretchesTable extends StatelessWidget {
  final List<MeasuredDistance> _data;
  final void Function(int index)? onDelete;
  final void Function(int index, MeasuredDistance stretch)? onUpdate;

  const StretchesTable({
    super.key,
    required List<MeasuredDistance> data,
    this.onDelete,
    this.onUpdate,
  }) : _data = data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showActions = onDelete != null;

    return Table(
      border: TableBorder.all(),
      columnWidths: showActions ? const {5: FixedColumnWidth(48)} : null,
      children: [
        TableRow(
          children: [
            TableCell(child: _HeaderCell(text: l10n.columnFrom)),
            TableCell(child: _HeaderCell(text: l10n.columnTo)),
            TableCell(child: _HeaderCell(text: l10n.columnDistance)),
            TableCell(child: _HeaderCell(text: l10n.columnAzimuth)),
            TableCell(child: _HeaderCell(text: l10n.columnInclination)),
            if (showActions) const TableCell(child: SizedBox.shrink()),
          ],
        ),
        for (var i = 0; i < _data.length; i++)
          _buildRow(context, i, _data[i], showActions),
      ],
    );
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
    onUpdate?.call(index, updated);
  }

  TableRow _buildRow(
    BuildContext context,
    int index,
    MeasuredDistance stretch,
    bool showActions,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return TableRow(
      children: [
        TableCell(
          child: _PointCell(
            point: stretch.from,
            onChanged: (p) => _updateStretch(index, stretch, from: p),
          ),
        ),
        TableCell(
          child: _PointCell(
            point: stretch.to,
            onChanged: (p) => _updateStretch(index, stretch, to: p),
          ),
        ),
        TableCell(
          child: _NumberCell(
            value: stretch.distance,
            onChanged: (v) => _updateStretch(index, stretch, distance: v),
          ),
        ),
        TableCell(
          child: _NumberCell(
            value: stretch.azimut,
            onChanged: (v) => _updateStretch(index, stretch, azimut: v),
          ),
        ),
        TableCell(
          child: _NumberCell(
            value: stretch.inclination,
            signed: true,
            onChanged: (v) => _updateStretch(index, stretch, inclination: v),
          ),
        ),
        if (showActions)
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => onDelete?.call(index),
              tooltip: l10n.deleteStretch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
      ],
    );
  }
}

class _PointCell extends StatefulWidget {
  final Point point;
  final void Function(Point)? onChanged;

  const _PointCell({required this.point, this.onChanged});

  @override
  State<_PointCell> createState() => _PointCellState();
}

class _PointCellState extends State<_PointCell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.point.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_PointCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point != widget.point && !_focusNode.hasFocus) {
      _controller.text = widget.point.toString();
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
    }
  }

  void _saveValue() {
    final value = _controller.text;
    final parts = value.split('.');
    if (parts.length == 2) {
      final corridor = num.tryParse(parts[0]);
      final point = num.tryParse(parts[1]);
      if (corridor != null && point != null) {
        widget.onChanged?.call(Point(corridor, point));
        return;
      }
    }
    // Reset to original value if parsing fails
    _controller.text = widget.point.toString();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.all(8),
        border: InputBorder.none,
      ),
      onSubmitted: (_) => _saveValue(),
    );
  }
}

class _NumberCell extends StatefulWidget {
  final num value;
  final bool signed;
  final void Function(num)? onChanged;

  const _NumberCell({
    required this.value,
    this.signed = false,
    this.onChanged,
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
  }

  String _formatValue(num value) {
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
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.all(8),
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
      onSubmitted: (_) => _saveValue(),
    );
  }
}

class ReferencePointsTable extends StatelessWidget {
  final List<ReferencePoint> _data;

  const ReferencePointsTable({super.key, required List<ReferencePoint> data})
      : _data = data;

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
        for (final point in _data)
          TableRow(
            children: [
              TableCell(
                child: _DataTableCell(text: point.id.toString()),
              ),
              TableCell(
                child: _DataTableCell(text: point.east.toString()),
              ),
              TableCell(
                child: _DataTableCell(text: point.north.toString()),
              ),
              TableCell(
                child: _DataTableCell(text: point.altitude.toString()),
              ),
            ],
          ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _DataTableCell extends StatelessWidget {
  const _DataTableCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text),
    );
  }
}
