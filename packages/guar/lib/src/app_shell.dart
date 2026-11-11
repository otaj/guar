// Bottom navigation between the ledger screens.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guar/src/directives_screen.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar/src/open_account_screen.dart';
import 'package:guar/src/plugins_screen.dart';
import 'package:guar/src/settings_screen.dart';
import 'package:guar/src/transaction_editor_screen.dart';

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

  bool get _advanced => _session.snapshot?.options.guar.advancedUi ?? false;

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
    if (_session.loading && _session.snapshot == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
      floatingActionButton: loaded
          ? FloatingActionButton(
              key: const Key('add-transaction'),
              heroTag: 'add-transaction',
              onPressed: _addTransaction,
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Future<void> _addTransaction() async {
    await _session.flush();
    if (!mounted) return;
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _AddOptionRow(
                key: const Key('add-transaction-option'),
                icon: Icons.receipt_long,
                label: 'New transaction',
                onTap: () => Navigator.pop(context, 'transaction'),
              ),
              _AddOptionRow(
                key: const Key('add-account-option'),
                icon: Icons.account_balance_wallet_outlined,
                label: 'New account',
                onTap: () => Navigator.pop(context, 'account'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'account') {
      await _openAccount();
      return;
    }
    final Object? result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(builder: (BuildContext context) => TransactionEditorScreen(session: _session)),
    );
    if (result == 'plugins' && mounted) {
      setState(() => _tab = _Tab.plugins);
    }
  }

  Future<void> _openAccount() async {
    await _session.flush();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => OpenAccountScreen(session: _session)),
    );
  }

  Future<void> _select(_Tab tab) async {
    if (tab == _tab) return;
    await _session.flush();
    if (!mounted) return;
    setState(() => _tab = tab);
  }
}

class _AddOptionRow extends StatelessWidget {
  const _AddOptionRow({required this.icon, required this.label, required this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.secondaryContainer),
                  alignment: Alignment.center,
                  child: Icon(icon, color: colors.onSecondaryContainer, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
