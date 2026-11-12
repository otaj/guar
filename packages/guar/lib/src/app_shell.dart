// Bottom navigation between the ledger screens.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guar/l10n/gen/app_localizations.dart';
import 'package:guar/src/balances_screen.dart';
import 'package:guar/src/directives_screen.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar/src/open_account_screen.dart';
import 'package:guar/src/plugins_screen.dart';
import 'package:guar/src/prices_screen.dart';
import 'package:guar/src/settings_screen.dart';
import 'package:guar/src/transaction_editor_screen.dart';

enum _Tab {
  ledger(Icons.list_alt_outlined, Icons.list_alt),
  balances(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
  prices(Icons.sell_outlined, Icons.sell, advancedOnly: true),
  plugins(Icons.extension_outlined, Icons.extension, advancedOnly: true),
  settings(Icons.tune_outlined, Icons.tune);

  const _Tab(this.icon, this.selectedIcon, {this.advancedOnly = false});

  final IconData icon;
  final IconData selectedIcon;

  // Hidden with the plugins screen unless advanced mode is on.
  final bool advancedOnly;

  String label(GuarLocalizations l10n) => switch (this) {
    _Tab.ledger => l10n.tabLedger,
    _Tab.balances => l10n.tabBalances,
    _Tab.prices => l10n.tabPrices,
    _Tab.plugins => l10n.tabPlugins,
    _Tab.settings => l10n.tabSettings,
  };

  NavigationDestination destination(GuarLocalizations l10n) => NavigationDestination(
    icon: Icon(icon),
    selectedIcon: Icon(selectedIcon),
    label: label(l10n),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({required this.session, super.key});

  final LedgerSession session;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  LedgerSession get _session => widget.session;
  _Tab _tab = _Tab.settings;
  String? _openUri;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
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
      } else if (!_advanced && _tab.advancedOnly) {
        _tab = _Tab.settings;
      }
      _openUri = uri;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final GuarLocalizations l10n = GuarLocalizations.of(context);
    if (_session.loading && _session.snapshot == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final bool loaded = _session.settled && _session.document != null;
    final bool advanced = loaded && _advanced;
    final _Tab visible = !loaded || (!advanced && _tab.advancedOnly) ? _Tab.settings : _tab;
    final List<_Tab> tabs = <_Tab>[
      if (loaded) _Tab.ledger,
      if (loaded) _Tab.balances,
      if (loaded && advanced) _Tab.prices,
      if (loaded && advanced) _Tab.plugins,
      _Tab.settings,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(visible.label(l10n))),
      body: IndexedStack(
        index: visible.index,
        children: <Widget>[
          for (final _Tab tab in _Tab.values)
            switch (tab) {
              _Tab.ledger => DirectivesScreen(
                key: const Key('directives'),
                session: _session,
                onPluginsRequested: () => setState(() => _tab = _Tab.plugins),
              ),
              _Tab.balances => BalancesScreen(key: const Key('balances'), session: _session),
              _Tab.prices => PricesScreen(key: const Key('prices'), session: _session),
              _Tab.plugins => PluginsScreen(key: const Key('plugins'), session: _session),
              _Tab.settings => SettingsScreen(key: const Key('settings'), session: _session),
            },
        ],
      ),
      bottomNavigationBar: loaded
          ? NavigationBar(
              selectedIndex: tabs.indexOf(visible),
              destinations: <NavigationDestination>[for (final _Tab tab in tabs) tab.destination(l10n)],
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
                label: GuarLocalizations.of(context).newTransaction,
                onTap: () => Navigator.pop(context, 'transaction'),
              ),
              _AddOptionRow(
                key: const Key('add-account-option'),
                icon: Icons.account_balance_wallet_outlined,
                label: GuarLocalizations.of(context).newAccount,
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
