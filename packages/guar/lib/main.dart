// Guar app: ledger settings for the chosen Beancount file.
import 'package:flutter/material.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/settings_screen.dart';

void main() => runApp(const MainApp(documents: PlatformLedgerDocuments()));

class MainApp extends StatelessWidget {
  const MainApp({required this.documents, super.key});

  final LedgerDocuments documents;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: SettingsScreen(documents: documents),
  );
}

const Color _seed = Color(0xFF1B6B43);

const ButtonStyle _buttons = ButtonStyle(
  minimumSize: WidgetStatePropertyAll<Size>(Size.fromHeight(52)),
);

ThemeData _theme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
  filledButtonTheme: const FilledButtonThemeData(style: _buttons),
);
