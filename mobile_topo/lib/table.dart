import 'package:flutter/material.dart';
import 'topo.dart';

class StretchesTable extends StatelessWidget {
  final List<MeasuredDistance> _data;

  const StretchesTable({super.key, required List<MeasuredDistance> data})
      : _data = data;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(),
      children: [
        const TableRow(
          children: [
            TableCell(child: Text('From')),
            TableCell(child: Text('To')),
            TableCell(child: Text('Dist.')),
            TableCell(child: Text('Azi.')),
            TableCell(child: Text('Incl.')),
          ],
        ),
        for (final distance in _data)
          TableRow(
            children: [
              TableCell(
                child:
                    _DataTableCell(text: distance.from.corridorId.toString()),
              ),
              TableCell(
                child: _DataTableCell(text: distance.to.corridorId.toString()),
              ),
              TableCell(
                child: _DataTableCell(text: distance.distance.toString()),
              ),
              TableCell(
                child: _DataTableCell(text: distance.azimut.toString()),
              ),
              TableCell(
                child: _DataTableCell(text: distance.inclination.toString()),
              ),
            ],
          ),
      ],
    );
  }
}

class ReferencePointsTable extends StatelessWidget {
  final List<ReferencePoint> _data;

  const ReferencePointsTable({super.key, required List<ReferencePoint> data})
      : _data = data;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(),
      children: [
        const TableRow(
          children: [
            TableCell(child: Text('ID')),
            TableCell(child: Text('East')),
            TableCell(child: Text('North')),
            TableCell(child: Text('Alt.')),
          ],
        ),
        for (final point in _data)
          TableRow(
            children: [
              TableCell(
                child: _DataTableCell(
                    text: '${point.id.corridorId}.${point.id.pointId}'),
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

class _DataTableCell extends StatelessWidget {
  const _DataTableCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: TextFormField(
        initialValue: text,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.all(1.0),
        ),
      ),
    );
  }
}
