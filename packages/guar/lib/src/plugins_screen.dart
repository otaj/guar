// Turn known plugins on or off, configure them, and arrange the order they run in.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guar/l10n/gen/app_localizations.dart';
import 'package:guar/src/app_errors.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar/src/plugin_editor.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_plugins/guar_plugins.dart';

class PluginsScreen extends StatefulWidget {
  const PluginsScreen({required this.session, super.key});

  final LedgerSession session;

  @override
  State<PluginsScreen> createState() => _PluginsScreenState();
}

class _Row {
  _Row({required this.id, required this.name, required this.config});

  final int id;
  final String name;
  String? config;
}

class _PluginsScreenState extends State<PluginsScreen> {
  final List<_Row> _rows = <_Row>[];

  int _seen = 0;
  int _nextId = 0;
  bool _closed = false;
  bool _pumping = false;
  bool _again = false;
  String? _error;
  VoidCallback? _unbindFlush;

  @override
  void initState() {
    super.initState();
    _unbindFlush = widget.session.bindFlush(flushPending);
    widget.session.addListener(_onSession);
    if (widget.session.generation != _seen) {
      _seen = widget.session.generation;
      _loadRows();
    }
  }

  @override
  void dispose() {
    _closed = true;
    widget.session.removeListener(_onSession);
    _unbindFlush?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final GuarLocalizations l10n = GuarLocalizations.of(context);
    final LedgerSession session = widget.session;
    final String? error = sessionMessage(session, l10n) ?? _error;
    if (!session.settled) return const SizedBox.shrink();
    if (session.document == null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          l10n.noLedgerSelectedSettings,
          style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
      );
    }
    final List<PluginDeclaration> available = _available();
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(session.document!.displayName, style: text.titleMedium),
                const SizedBox(height: 8),
                Text(
                  l10n.pluginsHint,
                  style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(error, style: text.bodyMedium?.copyWith(color: colors.error)),
                ],
                if (session.busy || session.loading) ...<Widget>[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
        if (_rows.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
              child: Text(l10n.noPluginsOn, style: text.bodyLarge),
            ),
          ),
        SliverReorderableList(
          itemCount: _rows.length,
          onReorderItem: _reorder,
          itemBuilder: (BuildContext context, int index) {
            final _Row row = _rows[index];
            final PluginDeclaration? spec = _spec(row.name);
            return PluginEditor(
              key: ValueKey<int>(row.id),
              name: row.name,
              description: spec?.description,
              setup: spec?.setup,
              config: row.config,
              enabled: true,
              reorderIndex: index,
              bindFlush: widget.session.bindFlush,
              onToggle: (bool value) {
                if (!value) _disable(row.id);
              },
              onChanged: (String? config) => _onChanged(row.id, config),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child: Text(l10n.availableTitle, style: text.titleLarge),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
            final PluginDeclaration spec = available[index];
            return PluginEditor(
              key: ValueKey<String>(spec.name),
              name: spec.name,
              description: spec.description,
              setup: spec.setup,
              enabled: false,
              bindFlush: widget.session.bindFlush,
              onToggle: (bool value) {
                if (value) _enable(spec);
              },
              onChanged: (String? config) => Future<void>.value(),
            );
          }, childCount: available.length),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Future<void> flushPending() => _pump();

  void _onSession() {
    if (!mounted || _closed) return;
    if (_seen == widget.session.generation) {
      setState(() {});
      return;
    }
    _seen = widget.session.generation;
    _loadRows();
    setState(() => _error = null);
  }

  void _loadRows() {
    _rows.clear();
    final List<LedgerPlugin>? plugins = widget.session.snapshot?.plugins;
    if (plugins == null) return;
    for (final LedgerPlugin plugin in plugins) {
      _rows.add(_Row(id: _nextId++, name: plugin.name, config: plugin.config));
    }
  }

  List<PluginDeclaration> _available() => <PluginDeclaration>[
    for (final PluginDeclaration plugin in pluginCatalog)
      if (!_rows.any((_Row row) => row.name == plugin.name)) plugin,
  ];

  PluginDeclaration? _spec(String name) {
    for (final PluginDeclaration plugin in pluginCatalog) {
      if (plugin.name == name) return plugin;
    }
    return null;
  }

  void _enable(PluginDeclaration plugin) {
    final PluginSetup? setup = plugin.setup;
    final String? config = setup?.encode(setup.decode(null)).config;
    setState(() {
      _rows.add(_Row(id: _nextId++, name: plugin.name, config: config));
      _error = null;
    });
    unawaited(_pump());
  }

  void _disable(int id) {
    setState(() {
      _rows.removeWhere((_Row row) => row.id == id);
      _error = null;
    });
    unawaited(_pump());
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final _Row row = _rows.removeAt(oldIndex);
      _rows.insert(newIndex, row);
    });
    unawaited(_pump());
  }

  Future<void> _onChanged(int id, String? config) {
    final int index = _rows.indexWhere((_Row row) => row.id == id);
    if (index < 0 || _rows[index].config == config) return Future<void>.value();
    _rows[index].config = config;
    return _pump();
  }

  Future<void> _pump() async {
    if (widget.session.document == null) return;
    if (_pumping) {
      _again = true;
      return;
    }
    _pumping = true;
    try {
      do {
        _again = false;
        await _saveOnce();
      } while (_again && !_closed);
    } finally {
      _pumping = false;
    }
  }

  Future<void> _saveOnce() async {
    if (widget.session.document == null) return;
    try {
      await widget.session.savePlugins(<LedgerPlugin>[
        for (final _Row row in _rows) LedgerPlugin(name: row.name, config: row.config),
      ]);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }
}
