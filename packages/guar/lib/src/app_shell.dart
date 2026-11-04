// Bottom navigation between the ledger screens.

import 'dart:async';

import 'package:flutter/material.dart';
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
  static const int _pluginsTab = 0;
  static const int _settingsTab = 1;

  late final LedgerSession _session;
  int _index = _settingsTab;

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
    if (!_advanced) _index = _settingsTab;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool advanced = _advanced;
    return Scaffold(
      appBar: AppBar(title: Text(advanced && _index == _pluginsTab ? 'Plugins' : 'Settings')),
      body: IndexedStack(
        index: advanced ? _index : 0,
        children: <Widget>[
          if (advanced) PluginsScreen(key: const Key('plugins'), session: _session),
          SettingsScreen(key: const Key('settings'), session: _session),
        ],
      ),
      bottomNavigationBar: advanced
          ? NavigationBar(
              selectedIndex: _index,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.extension_outlined),
                  selectedIcon: Icon(Icons.extension),
                  label: 'Plugins',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune),
                  label: 'Settings',
                ),
              ],
              onDestinationSelected: (int next) => unawaited(_select(next)),
            )
          : null,
    );
  }

  Future<void> _select(int index) async {
    if (index == _index) return;
    await _session.flush();
    if (!mounted) return;
    setState(() => _index = index);
  }
}
