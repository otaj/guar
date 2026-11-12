// Guar app: the open ledger, and the screens that edit it.
import 'package:flutter/material.dart';
import 'package:guar/src/app_shell.dart';
import 'package:guar/src/ledger_documents.dart';

void main() => runApp(const MainApp(documents: PlatformLedgerDocuments()));

class MainApp extends StatelessWidget {
  const MainApp({required this.documents, super.key});

  final LedgerDocuments documents;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: AppShell(key: ObjectKey(documents), documents: documents),
  );
}

const Color _seed = Color(0xFF1B6B43);

const ButtonStyle _buttons = ButtonStyle(
  minimumSize: WidgetStatePropertyAll<Size>(Size.fromHeight(52)),
);

ThemeData _theme(Brightness brightness) {
  final ColorScheme colorScheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: colorScheme,
    filledButtonTheme: const FilledButtonThemeData(style: _buttons),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withAlpha(80),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
