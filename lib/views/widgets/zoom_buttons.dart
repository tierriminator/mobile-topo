import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Zoom factor of one press of a zoom button
const zoomButtonStep = 2.0;

/// Buttons zooming the map or sketch in and out, for when pinching is not
/// at hand, as with a stylus or a device in a case
class ZoomButtons extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const ZoomButtons({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          icon: const Icon(Icons.add),
          tooltip: l10n.zoomIn,
          onPressed: onZoomIn,
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.remove),
          tooltip: l10n.zoomOut,
          onPressed: onZoomOut,
        ),
      ],
    );
  }
}
