// One plugin row: switch, description, configuration, and an optional drag handle.

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar_plugins/guar_plugins.dart';

class PluginEditor extends StatefulWidget {
  const PluginEditor({
    required this.name,
    required this.enabled,
    required this.bindFlush,
    required this.onToggle,
    required this.onChanged,
    this.description,
    this.setup,
    this.config,
    this.reorderIndex,
    super.key,
  });

  final String name;
  final String? description;
  final PluginSetup? setup;
  final String? config;
  final bool enabled;
  final int? reorderIndex;
  final VoidCallback Function(Future<void> Function() flush) bindFlush;
  final ValueChanged<bool> onToggle;
  final Future<void> Function(String? config) onChanged;

  @override
  State<PluginEditor> createState() => _PluginEditorState();
}

class _Input {
  _Input(this.controller, this.focus);

  final TextEditingController controller;
  final FocusNode focus;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _RuleInputs {
  _RuleInputs({required this.name, required this.pattern, required this.inserts});

  final _Input name;
  final _Input pattern;
  final List<List<_Input>> inserts;

  void dispose() {
    name.dispose();
    pattern.dispose();
    for (final List<_Input> insert in inserts) {
      for (final _Input input in insert) {
        input.dispose();
      }
    }
  }
}

class _PluginEditorState extends State<PluginEditor> {
  final Map<String, _Input> _text = <String, _Input>{};
  final Map<String, bool> _flags = <String, bool>{};
  final Map<String, List<List<_Input>>> _tables = <String, List<List<_Input>>>{};
  final List<_RuleInputs> _rules = <_RuleInputs>[];

  _Input? _raw;
  String? _rulesId;
  String? _unparsedMessage;
  String? _error;
  bool _expanded = false;
  bool _dirty = false;
  bool _closed = false;
  bool _showConfig = false;
  Timer? _timer;
  late final VoidCallback _unbind;

  @override
  void initState() {
    super.initState();
    _unbind = widget.bindFlush(flush);
    _showConfig = widget.enabled && (widget.setup != null || widget.description == null);
    if (!_showConfig) return;
    final PluginSetup? setup = widget.setup;
    if (setup == null) {
      _raw = _input(widget.config ?? '');
      return;
    }
    final PluginStored stored = setup.decode(widget.config);
    if (!stored.structured) {
      _unparsedMessage = stored.message;
      _raw = _input(stored.raw ?? '');
      return;
    }
    for (final PluginField field in setup.fields) {
      switch (field) {
        case PluginTextField(:final String id):
          _text[id] = _input(stored.text[id] ?? '');
        case PluginDecimalField(:final String id):
          _text[id] = _input(stored.decimals[id]?.toString() ?? '');
        case PluginFlagField(:final String id):
          _flags[id] = stored.flags[id] ?? false;
        case PluginTableField(:final String id, :final List<PluginColumn> columns):
          _tables[id] = <List<_Input>>[
            for (final List<PluginCell> row in stored.tables[id] ?? const <List<PluginCell>>[])
              _cells(row, columns.length),
          ];
        case PluginRulesField(:final String id):
          _rulesId = id;
          _rules.addAll(<_RuleInputs>[
            for (final PluginRule rule in stored.rules[id] ?? const <PluginRule>[])
              _RuleInputs(
                name: _input(rule.name),
                pattern: _input(rule.pattern),
                inserts: <List<_Input>>[
                  for (final PluginInsert insert in rule.inserts)
                    <_Input>[_input(insert.account), _input(insert.currencies)],
                ],
              ),
          ]);
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    _unbind();
    _raw?.dispose();
    for (final _Input input in _text.values) {
      input.dispose();
    }
    for (final List<List<_Input>> table in _tables.values) {
      for (final List<_Input> row in table) {
        for (final _Input input in row) {
          input.dispose();
        }
      }
    }
    for (final _RuleInputs rule in _rules) {
      rule.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final int? reorderIndex = widget.reorderIndex;
    final String? shownError = _error;
    return Material(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (reorderIndex != null)
                  ReorderableDragStartListener(
                    index: reorderIndex,
                    child: Tooltip(
                      message: 'Drag to change the order',
                      child: Padding(
                        key: Key('drag-${widget.name}'),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(_label(widget.name), style: text.titleMedium),
                      Text(
                        widget.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('about-${widget.name}'),
                  tooltip: _expanded ? 'Hide description' : 'Show description',
                  onPressed: () {
                    if (_expanded) unawaited(flush());
                    setState(() => _expanded = !_expanded);
                  },
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ),
                Switch(
                  key: Key('toggle-${widget.name}'),
                  value: widget.enabled,
                  onChanged: widget.onToggle,
                ),
              ],
            ),
            if (_expanded) ...<Widget>[
              Text(widget.description ?? _unknown, style: text.bodyMedium),
              if (_showConfig) ..._configFields(text),
              if (shownError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(shownError, style: text.bodyMedium?.copyWith(color: colors.error)),
                ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _configFields(TextTheme text) {
    final _Input? raw = _raw;
    if (raw != null) {
      return <Widget>[
        if (_unparsedMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_unparsedMessage!, style: text.bodySmall),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextFormField(
            key: Key('config-${widget.name}-raw'),
            controller: raw.controller,
            focusNode: raw.focus,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Configuration', border: OutlineInputBorder()),
          ),
        ),
      ];
    }
    final PluginSetup? setup = widget.setup;
    if (setup == null) return const <Widget>[];
    return <Widget>[
      for (final PluginField field in setup.fields) ...<Widget>[
        const SizedBox(height: 8),
        switch (field) {
          PluginTextField() || PluginDecimalField() => _textField(field),
          PluginFlagField() => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(field.label),
            subtitle: field.hint.isEmpty ? null : Text(field.hint),
            value: _flags[field.id] ?? false,
            onChanged: (bool value) => _setFlag(field.id, value: value),
          ),
          PluginTableField() => _table(field, text),
          PluginRulesField() => _ruleList(field, text),
        },
      ],
    ];
  }

  Widget _textField(PluginField field) {
    final _Input input = _text[field.id]!;
    return TextFormField(
      key: Key('config-${widget.name}-${field.id}'),
      controller: input.controller,
      focusNode: input.focus,
      keyboardType: field is PluginDecimalField
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : null,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.hint.isEmpty ? null : field.hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _table(PluginTableField field, TextTheme text) {
    final List<List<_Input>> rows = _tables[field.id] ?? <List<_Input>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(field.label, style: text.titleSmall),
        if (field.hint.isNotEmpty) Text(field.hint, style: text.bodySmall),
        for (int index = 0; index < rows.length; index++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: <Widget>[
                for (int column = 0; column < field.columns.length; column++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      key: Key('config-${widget.name}-${field.id}-$index-$column'),
                      controller: rows[index][column].controller,
                      focusNode: rows[index][column].focus,
                      keyboardType: _keyboard(field.columns[column].kind),
                      decoration: InputDecoration(
                        labelText: field.columns[column].label,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => _removeTableRow(field.id, index),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: Key('add-${widget.name}-${field.id}'),
            onPressed: () => _addTableRow(field),
            child: Text('Add ${field.label}'),
          ),
        ),
      ],
    );
  }

  Widget _ruleList(PluginRulesField field, TextTheme text) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(field.label, style: text.titleSmall),
      if (field.hint.isNotEmpty) Text(field.hint, style: text.bodySmall),
      for (int index = 0; index < _rules.length; index++) _rule(index, text),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: Key('add-${widget.name}-${field.id}'),
          onPressed: _addRule,
          child: const Text('Add rule'),
        ),
      ),
    ],
  );

  Widget _rule(int index, TextTheme text) {
    final _RuleInputs rule = _rules[index];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            controller: rule.name.controller,
            focusNode: rule.name.focus,
            decoration: const InputDecoration(labelText: 'Rule name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: rule.pattern.controller,
            focusNode: rule.pattern.focus,
            decoration: const InputDecoration(labelText: 'Account pattern', border: OutlineInputBorder()),
          ),
          for (int insert = 0; insert < rule.inserts.length; insert++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: <Widget>[
                  TextFormField(
                    controller: rule.inserts[insert][0].controller,
                    focusNode: rule.inserts[insert][0].focus,
                    decoration: const InputDecoration(labelText: 'Account template', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: rule.inserts[insert][1].controller,
                    focusNode: rule.inserts[insert][1].focus,
                    decoration: const InputDecoration(labelText: 'Currencies template', border: OutlineInputBorder()),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(onPressed: () => _removeInsert(index, insert), icon: const Icon(Icons.close)),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => _addInsert(index), child: const Text('Add insert')),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _removeRule(index), child: const Text('Remove rule')),
          ),
        ],
      ),
    );
  }

  Future<void> flush() {
    _timer?.cancel();
    return _emit();
  }

  _Input _input(String text) {
    final TextEditingController controller = TextEditingController(text: text)..addListener(_schedule);
    final FocusNode focus = FocusNode();
    focus.addListener(() {
      if (!focus.hasFocus) {
        scheduleMicrotask(() {
          if (!_closed) unawaited(flush());
        });
      }
    });
    return _Input(controller, focus);
  }

  List<_Input> _cells(List<PluginCell> cells, int width) => <_Input>[
    for (int index = 0; index < width; index++) _input(index < cells.length ? _display(cells[index]) : ''),
  ];

  String _display(PluginCell cell) => switch (cell) {
    PluginTextCell(:final String value) => value,
    PluginDecimalCell(:final Decimal? value) => value?.toString() ?? '',
    PluginIntCell(:final int? value) => value?.toString() ?? '',
  };

  TextInputType? _keyboard(PluginColumnKind kind) => switch (kind) {
    PluginColumnKind.text => null,
    PluginColumnKind.decimal => const TextInputType.numberWithOptions(decimal: true, signed: true),
    PluginColumnKind.integer => const TextInputType.numberWithOptions(signed: true),
  };

  void _schedule() {
    if (_closed) return;
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(ledgerOptionSaveDelay, () => unawaited(_emit()));
  }

  Future<void> _emit() {
    if (!_dirty || _closed) return Future<void>.value();
    final PluginWrite written = _encode();
    final String? error = written.error;
    if (error != null) {
      if (mounted) setState(() => _error = error);
      return Future<void>.value();
    }
    _dirty = false;
    if (mounted && _error != null) setState(() => _error = null);
    return widget.onChanged(written.config);
  }

  PluginWrite _encode() {
    final _Input? raw = _raw;
    if (raw != null || widget.setup == null) {
      final String text = raw?.controller.text ?? '';
      if (text.contains('"')) return const PluginWrite.bad(pluginQuoteError);
      if (text.contains('\n') || text.contains('\r')) return const PluginWrite.bad(pluginLineError);
      return PluginWrite.ok(text.trim().isEmpty ? null : text);
    }
    final PluginWrite? typedError = _typedError();
    if (typedError != null) return typedError;
    return widget.setup!.encode(_collect());
  }

  PluginWrite? _typedError() {
    for (final PluginField field in widget.setup?.fields ?? const <PluginField>[]) {
      switch (field) {
        case PluginDecimalField(:final String id):
          final String raw = _text[id]?.controller.text.trim() ?? '';
          if (raw.isNotEmpty && Decimal.tryParse(raw) == null) return const PluginWrite.bad('Enter a decimal');
        case PluginTableField(:final String id, :final List<PluginColumn> columns):
          for (final List<_Input> row in _tables[id] ?? const <List<_Input>>[]) {
            for (int column = 0; column < columns.length && column < row.length; column++) {
              final String raw = row[column].controller.text.trim();
              if (raw.isEmpty) continue;
              final PluginWrite? error = _cellError(columns[column].kind, raw);
              if (error != null) return error;
            }
          }
        case PluginTextField() || PluginFlagField() || PluginRulesField():
          break;
      }
    }
    return null;
  }

  PluginWrite? _cellError(PluginColumnKind kind, String raw) => switch (kind) {
    PluginColumnKind.text => null,
    PluginColumnKind.decimal => Decimal.tryParse(raw) == null ? const PluginWrite.bad('Enter a decimal') : null,
    PluginColumnKind.integer => int.tryParse(raw) == null ? const PluginWrite.bad('Enter a whole number') : null,
  };

  PluginStored _collect() => PluginStored(
    text: <String, String>{
      for (final PluginField field in widget.setup?.fields ?? const <PluginField>[])
        if (field is PluginTextField) field.id: _text[field.id]!.controller.text,
    },
    decimals: <String, Decimal>{
      for (final PluginField field in widget.setup?.fields ?? const <PluginField>[])
        if (field is PluginDecimalField && _text[field.id]!.controller.text.trim().isNotEmpty)
          field.id: Decimal.parse(_text[field.id]!.controller.text.trim()),
    },
    flags: Map<String, bool>.of(_flags),
    tables: <String, List<List<PluginCell>>>{
      for (final PluginField field in widget.setup?.fields ?? const <PluginField>[])
        if (field is PluginTableField)
          field.id: <List<PluginCell>>[
            for (final List<_Input> row in _tables[field.id] ?? const <List<_Input>>[])
              <PluginCell>[
                for (int column = 0; column < field.columns.length; column++)
                  _storedCell(field.columns[column], column < row.length ? row[column].controller.text : ''),
              ],
          ],
    },
    rules: _rulesId == null
        ? const <String, List<PluginRule>>{}
        : <String, List<PluginRule>>{
            _rulesId!: <PluginRule>[
              for (final _RuleInputs rule in _rules)
                PluginRule(
                  name: rule.name.controller.text,
                  pattern: rule.pattern.controller.text,
                  inserts: <PluginInsert>[
                    for (final List<_Input> insert in rule.inserts)
                      PluginInsert(account: insert[0].controller.text, currencies: insert[1].controller.text),
                  ],
                ),
            ],
          },
  );

  void _setFlag(String id, {required bool value}) {
    setState(() => _flags[id] = value);
    _dirty = true;
    unawaited(flush());
  }

  PluginCell _storedCell(PluginColumn column, String raw) {
    final String trimmed = raw.trim();
    return switch (column.kind) {
      PluginColumnKind.text => PluginTextCell(raw),
      PluginColumnKind.decimal => PluginDecimalCell(trimmed.isEmpty ? null : Decimal.parse(trimmed)),
      PluginColumnKind.integer => PluginIntCell(trimmed.isEmpty ? null : int.parse(trimmed)),
    };
  }

  void _addTableRow(PluginTableField field) {
    setState(() => (_tables[field.id] ??= <List<_Input>>[]).add(_cells(const <PluginCell>[], field.columns.length)));
    _dirty = true;
    unawaited(flush());
  }

  void _removeTableRow(String id, int index) {
    final List<_Input> row = _tables[id]!.removeAt(index);
    for (final _Input input in row) {
      input.dispose();
    }
    setState(() {});
    _dirty = true;
    unawaited(flush());
  }

  void _addRule() {
    setState(
      () => _rules.add(_RuleInputs(name: _input(''), pattern: _input(''), inserts: <List<_Input>>[])),
    );
    _dirty = true;
    unawaited(flush());
  }

  void _removeRule(int index) {
    _rules.removeAt(index).dispose();
    setState(() {});
    _dirty = true;
    unawaited(flush());
  }

  void _addInsert(int index) {
    setState(() => _rules[index].inserts.add(<_Input>[_input(''), _input('')]));
    _dirty = true;
    unawaited(flush());
  }

  void _removeInsert(int rule, int insert) {
    final List<_Input> row = _rules[rule].inserts.removeAt(insert);
    for (final _Input input in row) {
      input.dispose();
    }
    setState(() {});
    _dirty = true;
    unawaited(flush());
  }
}

const String _unknown =
    'This plugin is not one of the built-in plugins. Its configuration is kept as written in the ledger.';

String _label(String name) {
  final int dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return name;
  return name.substring(dot + 1);
}
