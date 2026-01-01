import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Text(l10n.mapViewPlaceholder),
    );
  }
}
