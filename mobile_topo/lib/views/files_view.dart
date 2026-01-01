import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class FilesView extends StatelessWidget {
  const FilesView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Text(l10n.filesViewPlaceholder),
    );
  }
}
