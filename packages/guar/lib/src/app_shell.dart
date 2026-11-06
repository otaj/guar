// Bottom navigation between the ledger screens.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guar/src/directives_screen.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar/src/plugins_screen.dart';
import 'package:guar/src/settings_screen.dart';
import 'package:guar_book/guar_book.dart';

enum _Tab {
  ledger('Ledger', Icons.list_alt_outlined, Icons.list_alt),
  plugins('Plugins', Icons.extension_outlined, Icons.extension),
  settings('Settings', Icons.tune_outlined, Icons.tune);

  const _Tab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  NavigationDestination get destination => NavigationDestination(
    icon: Icon(icon),
    selectedIcon: Icon(selectedIcon),
    label: label,
  );
}

class AppShell extends StatefulWidget {
  const AppShell({required this.documents, super.key});

  final LedgerDocuments documents;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final LedgerSession _session;
  _Tab _tab = _Tab.settings;
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
      // A newly opened ledger starts on the ledger tab. Later edits keep the current tab.
      if (uri == null) {
        _tab = _Tab.settings;
      } else if (uri != _openUri) {
        _tab = _Tab.ledger;
      } else if (!_advanced && _tab == _Tab.plugins) {
        _tab = _Tab.settings;
      }
      _openUri = uri;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool loaded = _session.settled && _session.document != null;
    final bool advanced = loaded && _advanced;
    final _Tab visible = !loaded || (!advanced && _tab == _Tab.plugins) ? _Tab.settings : _tab;
    final List<_Tab> tabs = <_Tab>[
      if (loaded) _Tab.ledger,
      if (loaded && advanced) _Tab.plugins,
      _Tab.settings,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(visible.label)),
      body: IndexedStack(
        index: visible.index,
        children: <Widget>[
          for (final _Tab tab in _Tab.values)
            switch (tab) {
              _Tab.ledger => DirectivesScreen(key: const Key('directives'), session: _session),
              _Tab.plugins => PluginsScreen(key: const Key('plugins'), session: _session),
              _Tab.settings => SettingsScreen(key: const Key('settings'), session: _session),
            },
        ],
      ),
      bottomNavigationBar: loaded
          ? NavigationBar(
              selectedIndex: tabs.indexOf(visible),
              destinations: <NavigationDestination>[for (final _Tab tab in tabs) tab.destination],
              onDestinationSelected: (int next) => unawaited(_select(tabs[next])),
            )
          : null,
    );
  }

  Future<void> _select(_Tab tab) async {
    if (tab == _tab) return;
    await _session.flush();
    if (!mounted) return;
    setState(() => _tab = tab);
  }
}
