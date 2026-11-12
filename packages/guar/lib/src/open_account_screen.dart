// The open-account editor: name and date, or every open-directive part in advanced mode.

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:guar/l10n/gen/app_localizations.dart';
import 'package:guar/src/app_errors.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar_domain/guar_domain.dart' as d;

class OpenAccountScreen extends StatefulWidget {
  const OpenAccountScreen({required this.session, super.key});

  final LedgerSession session;

  @override
  State<OpenAccountScreen> createState() => _OpenAccountScreenState();
}

class _MetaDraft {
  String key = '';
  String value = '';
  String type = 'text';
}

class _OpenAccountScreenState extends State<OpenAccountScreen> {
  final TextEditingController _date = TextEditingController(text: _today());
  final TextEditingController _account = TextEditingController();
  final TextEditingController _currencies = TextEditingController();
  final List<_MetaDraft> _meta = <_MetaDraft>[];
  d.BookingMethod? _booking;
  List<String> _errors = const <String>[];
  Timer? _debounce;

  bool get _advanced => widget.session.snapshot?.options.guar.advancedUi ?? false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _queueCheck();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.session.removeListener(_onSession);
    _date.dispose();
    _account.dispose();
    _currencies.dispose();
    super.dispose();
  }

  void _onSession() {
    if (mounted) {
      setState(() {});
      _queueCheck();
    }
  }

  static String _today() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  d.BeanDate? _parseDate(String text) {
    final List<String> parts = text.split('-');
    if (parts.length != 3) return null;
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return d.isValidBeanDate(year, month, day) ? d.BeanDate(year: year, month: month, day: day) : null;
  }

  static List<String> _splitList(String text) => <String>[
    for (final String item in text.split(RegExp(r'[,\s]+')))
      if (item.trim().isNotEmpty) item.trim(),
  ];

  String? _snippet() {
    final d.BeanDate? date = _parseDate(_date.text);
    final String name = _account.text.trim();
    if (date == null || !d.isValidAccountName(name)) return null;
    final List<String> header = <String>['$date open $name'];
    final List<String> lines = <String>[];
    if (_advanced) {
      final List<String> currencies = _splitList(_currencies.text);
      for (final String currency in currencies) {
        if (!d.isValidCurrencyName(currency)) return null;
      }
      if (currencies.isNotEmpty) header.add(currencies.join(','));
      if (_booking != null) header.add('"${_bookingText(_booking!)}"');
      for (final String? line in _meta.map(_metaLine)) {
        if (line == null) return null;
        lines.add('  $line');
      }
    }
    return '${<String>[header.join(' '), ...lines].join('\n')}\n';
  }

  String? _metaLine(_MetaDraft row) {
    final String key = row.key.trim();
    final String value = row.value.trim();
    if (key.isEmpty) return null;
    if (key.contains('"')) return null;
    if (value.isEmpty) return key;
    final String? rendered = switch (row.type) {
      'text' => value.contains('"') ? null : '"$value"',
      'number' => Decimal.tryParse(value) == null ? null : value,
      'date' => switch (_parseDate(value)) {
        null => null,
        final d.BeanDate date => date.toString(),
      },
      'account' => d.isValidAccountName(value) ? value : null,
      'currency' => d.isValidCurrencyName(value) ? value : null,
      'tag' => d.isValidTagOrLinkName(value) ? '#$value' : null,
      'boolean' => value.toUpperCase() == 'TRUE' ? 'TRUE' : 'FALSE',
      _ => null,
    };
    return rendered == null ? null : '$key: $rendered';
  }

  void _queueCheck() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _check);
  }

  Future<void> _check() async {
    final String? snippet = _snippet();
    if (snippet == null) {
      if (mounted) setState(() => _errors = const <String>[]);
      return;
    }
    final List<String> errors = await widget.session.validateTransaction(
      widget.session.document?.displayName ?? '',
      snippet,
    );
    if (mounted) setState(() => _errors = errors);
  }

  bool get _canSave => _snippet() != null && _errors.isEmpty;

  Future<void> _save() async {
    final String? snippet = _snippet();
    if (snippet == null || !_canSave) return;
    await widget.session.flush();
    await widget.session.addTransaction(widget.session.document?.displayName ?? '', snippet);
    if (!mounted) return;
    final String? message = sessionMessage(widget.session, GuarLocalizations.of(context));
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final GuarLocalizations l10n = GuarLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.openAccount)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextFormField(
            key: const Key('date'),
            controller: _date,
            decoration: InputDecoration(labelText: l10n.labelDate),
            onChanged: (String _) => _queueCheck(),
          ),
          TextFormField(
            key: const Key('account'),
            controller: _account,
            decoration: InputDecoration(labelText: l10n.labelAccount),
            onChanged: (String _) => _queueCheck(),
          ),
          if (_advanced) ...<Widget>[
            TextFormField(
              key: const Key('currencies'),
              controller: _currencies,
              decoration: InputDecoration(labelText: l10n.labelCurrenciesComma),
              onChanged: (String _) => _queueCheck(),
            ),
            DropdownButtonFormField<d.BookingMethod?>(
              key: const Key('booking'),
              initialValue: _booking,
              decoration: InputDecoration(labelText: l10n.labelBookingMethod),
              items: <DropdownMenuItem<d.BookingMethod?>>[
                DropdownMenuItem<d.BookingMethod?>(child: Text(l10n.bookingDefault)),
                for (final d.BookingMethod method in d.BookingMethod.values)
                  DropdownMenuItem<d.BookingMethod?>(value: method, child: Text(_bookingText(method))),
              ],
              onChanged: (d.BookingMethod? booking) {
                if (mounted) {
                  setState(() => _booking = booking);
                }
                _queueCheck();
              },
            ),
            ..._metaSection(),
          ],
          for (final String error in _errors)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                appendErrorText(l10n, error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('save'),
            onPressed: _canSave ? _save : null,
            child: Text(l10n.openAccount),
          ),
        ],
      ),
    );
  }

  List<Widget> _metaSection() {
    final GuarLocalizations l10n = GuarLocalizations.of(context);
    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: <Widget>[
            Text(l10n.metadata),
            IconButton(
              key: const Key('add-meta'),
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() => _meta.add(_MetaDraft()));
                _queueCheck();
              },
            ),
          ],
        ),
      ),
      for (int index = 0; index < _meta.length; index++)
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                key: Key('meta-$index-key'),
                controller: TextEditingController(text: _meta[index].key),
                decoration: InputDecoration(labelText: l10n.keyLabel),
                onChanged: (String value) {
                  _meta[index].key = value;
                  _queueCheck();
                },
              ),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _meta[index].type,
                items: <DropdownMenuItem<String>>[
                  for (final String type in const <String>[
                    'text',
                    'number',
                    'date',
                    'account',
                    'currency',
                    'tag',
                    'boolean',
                  ])
                    DropdownMenuItem<String>(value: type, child: Text(type)),
                ],
                onChanged: (String? type) {
                  if (type != null) {
                    setState(() => _meta[index].type = type);
                    _queueCheck();
                  }
                },
              ),
            ),
            Expanded(
              child: TextFormField(
                key: Key('meta-$index-value'),
                controller: TextEditingController(text: _meta[index].value),
                decoration: InputDecoration(labelText: l10n.valueLabel),
                onChanged: (String value) {
                  _meta[index].value = value;
                  _queueCheck();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _meta.removeAt(index));
                _queueCheck();
              },
            ),
          ],
        ),
    ];
  }
}

String _bookingText(d.BookingMethod method) => switch (method) {
  d.BookingMethod.strict => 'STRICT',
  d.BookingMethod.strictWithSize => 'STRICT_WITH_SIZE',
  d.BookingMethod.none => 'NONE',
  d.BookingMethod.average => 'AVERAGE',
  d.BookingMethod.fifo => 'FIFO',
  d.BookingMethod.lifo => 'LIFO',
  d.BookingMethod.hifo => 'HIFO',
};
