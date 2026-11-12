// Guar app: the open ledger, and the screens that edit it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guar/l10n/gen/app_localizations.dart';
import 'package:guar/src/app_shell.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/ledger_session.dart';

void main() => runApp(const MainApp(documents: PlatformLedgerDocuments()));

class MainApp extends StatelessWidget {
  const MainApp({required this.documents, super.key});

  final LedgerDocuments documents;

  @override
  Widget build(BuildContext context) => LedgerRoot(
    key: ObjectKey(documents),
    documents: documents,
    builder: (BuildContext context, LedgerSession session, Locale? locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: GuarLocalizations.localizationsDelegates,
      supportedLocales: GuarLocalizations.supportedLocales,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: AppShell(session: session),
    ),
  );
}

// A fresh key per documents instance, so opening another ledger starts a new session.
class LedgerRoot extends StatefulWidget {
  const LedgerRoot({required this.documents, required this.builder, super.key});

  final LedgerDocuments documents;
  final Widget Function(BuildContext context, LedgerSession session, Locale? locale) builder;

  @override
  State<LedgerRoot> createState() => _LedgerRootState();
}

class _LedgerRootState extends State<LedgerRoot> {
  late final LedgerSession _session;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _session = LedgerSession(widget.documents)..addListener(_onSession);
    unawaited(_session.load());
  }

  @override
  void dispose() {
    _session
      ..removeListener(_onSession)
      ..dispose();
    super.dispose();
  }

  void _onSession() {
    if (mounted) {
      setState(() => _locale = ledgerLocale(_session.snapshot?.options.guar.language));
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _session, _locale);
}

// The language guar_option overrides the phone; null follows the phone, and
// Material's resolution falls back to English when nothing matches.
Locale? ledgerLocale(String? language) {
  if (language == null || language.isEmpty) return null;
  return GuarLocalizations.supportedLocales.contains(Locale(language))
      ? Locale(language)
      : GuarLocalizations.supportedLocales.first;
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
