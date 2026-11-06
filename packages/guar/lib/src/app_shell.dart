// Bottom navigation between the ledger screens.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guar/src/directives_screen.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar/src/plugins_screen.dart';
import 'package:guar/src/settings_screen.dart';
import 'package:guar_book/guar_book.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.documents, super.key});

  final LedgerDocuments documents;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const int _directivesTab = 0;
  static const int _pluginsTab = 1;
  static const int _settingsTab = 2;

  late final LedgerSession _session;
  int _index = _settingsTab;
  String? _openUri;

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

  bool get _advanced => readLedgerOptions(_session.source).guar.advancedUi;

  void _onSession() {
    if (!mounted) return;
    if (_session.settled) {
      final String? uri = _session.document?.uri;
      // A newly opened ledger starts on its directives. Later edits keep the current tab.
      if (uri == null) {
        _index = _settingsTab;
      } else if (uri != _openUri) {
        _index = _directivesTab;
      } else if (!_advanced && _index == _pluginsTab) {
        _index = _settingsTab;
      }
      _openUri = uri;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool loaded = _session.settled && _session.document != null;
    final bool advanced = loaded && _advanced;
    final int visible = !loaded || (!advanced && _index == _pluginsTab) ? _settingsTab : _index;
    return Scaffold(
      appBar: AppBar(title: Text(_title(visible))),
      body: IndexedStack(
        index: visible,
        children: <Widget>[
          DirectivesScreen(key: const Key('directives'), session: _session),
          PluginsScreen(key: const Key('plugins'), session: _session),
          SettingsScreen(key: const Key('settings'), session: _session),
        ],
      ),
      bottomNavigationBar: loaded
          ? NavigationBar(
              selectedIndex: _barIndex(visible, advanced: advanced),
              destinations: <NavigationDestination>[
                const NavigationDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  selectedIcon: Icon(Icons.list_alt),
                  label: 'Ledger',
                ),
                if (advanced)
                  const NavigationDestination(
                    icon: Icon(Icons.extension_outlined),
                    selectedIcon: Icon(Icons.extension),
                    label: 'Plugins',
                  ),
                const NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune),
                  label: 'Settings',
                ),
              ],
              onDestinationSelected: (int next) => unawaited(_select(_tabFor(next, advanced: advanced))),
            )
          : null,
    );
  }

  String _title(int visible) => switch (visible) {
    _directivesTab => 'Ledger',
    _pluginsTab => 'Plugins',
    _ => 'Settings',
  };

  int _barIndex(int visible, {required bool advanced}) => switch (visible) {
    _directivesTab => 0,
    _pluginsTab => 1,
    _ => advanced ? 2 : 1,
  };

  int _tabFor(int barIndex, {required bool advanced}) {
    if (!advanced && barIndex == 1) return _settingsTab;
    return barIndex;
  }

  Future<void> _select(int index) async {
    if (index == _index) return;
    await _session.flush();
    if (!mounted) return;
    setState(() => _index = index);
  }
}
