import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class SketchView extends StatelessWidget {
  const SketchView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Text(l10n.sketchViewPlaceholder),
    );
  }
}
