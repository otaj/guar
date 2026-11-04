// Bottom navigation between the ledger screens.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar/src/plugins_screen.dart';
import 'package:guar/src/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.documents, super.key});

  final LedgerDocuments documents;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final LedgerSession _session;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _session = LedgerSession(widget.documents);
    unawaited(_session.load());
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_index == 0 ? 'Settings' : 'Plugins')),
    body: IndexedStack(
      index: _index,
      children: <Widget>[
        SettingsScreen(session: _session),
        PluginsScreen(session: _session),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      destinations: const <NavigationDestination>[
        NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Settings'),
        NavigationDestination(
          icon: Icon(Icons.extension_outlined),
          selectedIcon: Icon(Icons.extension),
          label: 'Plugins',
        ),
      ],
      onDestinationSelected: (int index) => unawaited(_select(index)),
    ),
  );

  Future<void> _select(int index) async {
    if (index == _index) return;
    await _session.flush();
    if (!mounted) return;
    setState(() => _index = index);
  }
}
