import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/coordinate_system.dart';

/// The name of [system], with the zone and hemisphere for UTM
String coordinateSystemName(AppLocalizations l10n, CoordinateSystem system) =>
    switch (system) {
      SwissGrid() => l10n.coordinateSystemSwiss,
      Utm(:final zone, :final south) =>
        '${l10n.coordinateSystemUtm} $zone${south ? 'S' : 'N'}',
      Wgs84() => l10n.coordinateSystemWgs84,
    };

/// Choice of a coordinate system, with the zone and hemisphere for UTM
class CoordinateSystemField extends StatelessWidget {
  final CoordinateSystem value;
  final ValueChanged<CoordinateSystem> onChanged;

  /// The zone UTM starts with when chosen
  final Utm utmStart;

  const CoordinateSystemField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.utmStart,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final system = value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<Type>(
          initialValue: system.runtimeType,
          decoration: InputDecoration(labelText: l10n.caveCoordinateSystem),
          items: [
            DropdownMenuItem(
                value: SwissGrid, child: Text(l10n.coordinateSystemSwiss)),
            DropdownMenuItem(
                value: Utm, child: Text(l10n.coordinateSystemUtm)),
            DropdownMenuItem(
                value: Wgs84, child: Text(l10n.coordinateSystemWgs84)),
          ],
          onChanged: (type) => onChanged(switch (type) {
            const (Utm) => utmStart,
            const (Wgs84) => CoordinateSystem.wgs84,
            _ => CoordinateSystem.swiss,
          }),
        ),
        if (system is Utm) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: system.zone,
                  decoration: InputDecoration(labelText: l10n.caveUtmZone),
                  items: [
                    for (var zone = 1; zone <= 60; zone++)
                      DropdownMenuItem(value: zone, child: Text('$zone')),
                  ],
                  onChanged: (zone) =>
                      onChanged(Utm(zone!, south: system.south)),
                ),
              ),
              const SizedBox(width: 16),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.caveUtmNorth)),
                  ButtonSegment(value: true, label: Text(l10n.caveUtmSouth)),
                ],
                selected: {system.south},
                onSelectionChanged: (selected) =>
                    onChanged(Utm(system.zone, south: selected.single)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
