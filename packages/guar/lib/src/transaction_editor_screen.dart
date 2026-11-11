// The transaction editor: simple two-leg entry, or every transaction part in advanced mode.

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart' as d;

class TransactionEditorScreen extends StatefulWidget {
  const TransactionEditorScreen({required this.session, super.key});

  final LedgerSession session;

  @override
  State<TransactionEditorScreen> createState() => _TransactionEditorScreenState();
}

class _LegDraft {
  d.Account? account;
  String accountName = '';
  String number = '';
  String currency = '';
  String costNumber = '';
  String costCurrency = '';
  bool costTotal = false;
  String priceNumber = '';
  String priceCurrency = '';
  bool priceTotal = false;
  final List<_MetaDraft> meta = <_MetaDraft>[];
}

class _MetaDraft {
  String key = '';
  String value = '';
  String type = 'text';
}

class _TransactionEditorScreenState extends State<TransactionEditorScreen> {
  final TextEditingController _date = TextEditingController(text: _today());
  final TextEditingController _payee = TextEditingController();
  final TextEditingController _narration = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _links = TextEditingController();
  final List<_MetaDraft> _meta = <_MetaDraft>[];
  final List<_LegDraft> _legs = <_LegDraft>[_LegDraft(), _LegDraft()];
  d.SpecialFlag _flag = d.SpecialFlag.asterisk;
  String? _target;
  List<String> _errors = const <String>[];
  Timer? _debounce;

  bool get _advanced => widget.session.snapshot?.options.guar.advancedUi ?? false;

  bool get _freeAccounts => widget.session.snapshot?.options.guar.allowUnopenedAccounts ?? false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _defaultAccounts();
    _queueCheck();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.session.removeListener(_onSession);
    _date.dispose();
    _payee.dispose();
    _narration.dispose();
    _tags.dispose();
    _links.dispose();
    super.dispose();
  }

  void _onSession() {
    if (mounted) {
      setState(() {});
      // The ledger may have changed underneath the draft, so revalidate.
      _queueCheck();
    }
  }

  void _defaultAccounts() {
    final List<d.Account> accounts = _eligibleAccounts();
    final bool typed = _freeAccounts;
    if (_legs[0].account == null && !(typed && _legs[0].accountName.isNotEmpty)) {
      final d.Account? from = accounts
          .where(
            (d.Account account) => account.type == d.AccountType.assets || account.type == d.AccountType.liabilities,
          )
          .firstOrNull;
      if (from != null) _setAccount(_legs[0], from);
    }
    if (_legs[1].account == null && !(typed && _legs[1].accountName.isNotEmpty)) {
      final d.Account? to = accounts.where((d.Account account) => account.type == d.AccountType.expenses).firstOrNull;
      if (to != null) _setAccount(_legs[1], to);
    }
  }

  void _setAccount(_LegDraft leg, d.Account account) {
    leg
      ..account = account
      ..accountName = account.name;
  }

  List<d.Account> _eligibleAccounts() {
    final List<d.Directive> directives = _directives();
    final d.BeanDate? date = _parseDate(_date.text);
    final Map<String, d.BeanDate> opens = <String, d.BeanDate>{};
    final Map<String, d.BeanDate> closes = <String, d.BeanDate>{};
    final Map<String, d.Account> accounts = <String, d.Account>{};
    for (final d.Directive directive in directives) {
      switch (directive.body) {
        case d.OpenBody(:final d.Account account):
          opens[account.name] = directive.date;
          accounts[account.name] = account;
        case d.CloseBody(:final d.Account account):
          closes[account.name] = directive.date;
        default:
          break;
      }
    }
    return <d.Account>[
      for (final MapEntry<String, d.BeanDate> open in opens.entries)
        if (date == null || d.compareBeanDate(open.value, date) < 0)
          if (!closes.containsKey(open.key) || d.compareBeanDate(date!, closes[open.key]!) < 0) accounts[open.key]!,
    ];
  }

  List<d.Directive> _directives() => switch (widget.session.snapshot?.booked.ledger) {
    d.LedgerDirectives(:final List<d.Directive> directives) => directives,
    _ => const <d.Directive>[],
  };

  List<String> _targets() {
    final String root = widget.session.document?.displayName ?? '';
    final Set<String> files = <String>{
      for (final d.Directive directive in _directives())
        switch (directive.origin) {
          d.SourceOrigin(:final d.BeanLocation location) => location.filename,
          _ => '',
        },
    };
    return <String>[root, ...files.where((String file) => file.isNotEmpty && file != root)];
  }

  static String _today() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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

  d.Currency? _currency(String text) {
    final String name = text.trim();
    return d.isValidCurrencyName(name) ? d.Currency(name: name) : null;
  }

  Decimal? _number(String text) {
    final String trimmed = text.trim();
    return trimmed.isEmpty ? null : Decimal.tryParse(trimmed);
  }

  String _negateNumber(String text) {
    final Decimal value = Decimal.tryParse(text)!;
    if (value.compareTo(Decimal.zero) < 0) return text.substring(1);
    if (value == Decimal.zero) return text;
    return '-$text';
  }

  TransactionDraft? _draft() {
    final d.BeanDate? date = _parseDate(_date.text);
    if (date == null) return null;
    final String? payee = _payee.text.trim().isEmpty ? null : _payee.text.trim();
    if (payee?.contains('"') ?? false) return null;
    if (_narration.text.contains('"')) return null;
    final List<d.Tag> tags = <d.Tag>[];
    final List<d.Link> links = <d.Link>[];
    if (_advanced) {
      for (final String name in _splitList(_tags.text)) {
        if (!d.isValidTagOrLinkName(name)) return null;
        tags.add(d.Tag(name: name));
      }
      for (final String name in _splitList(_links.text)) {
        if (!d.isValidTagOrLinkName(name)) return null;
        links.add(d.Link(name: name));
      }
    }
    final d.Meta? meta = _metaOf(_meta);
    if (meta == null) return null;
    final List<TransactionDraftPosting> postings = <TransactionDraftPosting>[];
    if (!_advanced) {
      final String amount = _legs[0].number.trim();
      final d.Currency? currency = _currency(_legs[0].currency);
      final d.Account? from = _legs[0].account;
      final d.Account? to = _legs[1].account;
      if (_number(amount) == null || currency == null || from == null || to == null) return null;
      postings.addAll(<TransactionDraftPosting>[
        TransactionDraftPosting(
          account: from,
          units: TransactionDraftAmount(number: _negateNumber(amount), currency: currency),
        ),
        TransactionDraftPosting(
          account: to,
          units: TransactionDraftAmount(number: amount, currency: currency),
        ),
      ]);
    } else {
      for (final _LegDraft leg in _legs) {
        final d.Account? account = leg.account;
        if (account == null) continue;
        final d.Meta? legMeta = _metaOf(leg.meta);
        if (legMeta == null) return null;
        final d.Currency? unitsCurrency = _currency(leg.currency);
        if (leg.currency.trim().isNotEmpty && unitsCurrency == null) return null;
        final TransactionDraftCost? cost = _costOf(leg);
        final TransactionDraftPrice? price = _priceOf(leg);
        final String number = leg.number.trim();
        if (_number(number) == null && number.isNotEmpty) return null;
        postings.add(
          TransactionDraftPosting(
            account: account,
            units: number.isEmpty && unitsCurrency == null
                ? null
                : TransactionDraftAmount(number: number.isEmpty ? null : number, currency: unitsCurrency),
            cost: cost,
            price: price,
            meta: legMeta,
          ),
        );
      }
    }
    if (postings.length < 2) return null;
    return TransactionDraft(
      date: date,
      flag: d.Flag.special(_flag),
      payee: payee,
      narration: _narration.text.trim(),
      tags: tags,
      links: links,
      meta: meta,
      postings: postings,
    );
  }

  TransactionDraftCost? _costOf(_LegDraft leg) {
    final Decimal? number = _number(leg.costNumber);
    final d.Currency? currency = _currency(leg.costCurrency);
    if (leg.costNumber.trim().isNotEmpty && number == null) return null;
    if (leg.costCurrency.trim().isNotEmpty && currency == null) return null;
    if (number == null && currency == null) return null;
    return TransactionDraftCost(
      numberPer: leg.costTotal || leg.costNumber.trim().isEmpty ? null : leg.costNumber.trim(),
      numberTotal: leg.costTotal && leg.costNumber.trim().isNotEmpty ? leg.costNumber.trim() : null,
      currency: currency,
    );
  }

  TransactionDraftPrice? _priceOf(_LegDraft leg) {
    final Decimal? number = _number(leg.priceNumber);
    final d.Currency? currency = _currency(leg.priceCurrency);
    if (leg.priceNumber.trim().isNotEmpty && number == null) return null;
    if (leg.priceCurrency.trim().isNotEmpty && currency == null) return null;
    if (number == null && currency == null) return null;
    return TransactionDraftPrice(
      number: leg.priceNumber.trim().isEmpty ? null : leg.priceNumber.trim(),
      currency: currency,
      total: leg.priceTotal,
    );
  }

  d.Meta? _metaOf(List<_MetaDraft> rows) {
    final List<d.MetaEntry> entries = <d.MetaEntry>[];
    for (final _MetaDraft row in rows) {
      final String key = row.key.trim();
      if (key.isEmpty) continue;
      final String value = row.value.trim();
      final d.MetaValue? typed = switch (row.type) {
        'text' => value.isEmpty ? null : d.MetaValue.text(value),
        'number' =>
          value.isEmpty
              ? null
              : _number(value) == null
              ? null
              : d.MetaValue.number(_number(value)!),
        'date' =>
          value.isEmpty
              ? null
              : _parseDate(value) == null
              ? null
              : d.MetaValue.date(_parseDate(value)!),
        'account' =>
          value.isEmpty
              ? null
              : _domainAccount(value) == null
              ? null
              : d.MetaValue.account(_domainAccount(value)!),
        'currency' =>
          value.isEmpty
              ? null
              : _currency(value) == null
              ? null
              : d.MetaValue.currency(_currency(value)!),
        'tag' => value.isEmpty ? null : d.MetaValue.tag(d.Tag(name: value)),
        'boolean' => d.MetaValue.boolean(value.toUpperCase() == 'TRUE'),
        _ => null,
      };
      if (value.isNotEmpty && row.type != 'boolean' && typed == null) return null;
      entries.add(d.MetaEntry(key: key, value: typed));
    }
    return d.Meta(entries: entries);
  }

  d.Account? _domainAccount(String name) {
    if (!d.isValidAccountName(name)) return null;
    final d.AccountPrefixes prefixes =
        widget.session.snapshot?.options.options.accountPrefixes ?? const d.AccountPrefixes();
    return d.Account(name: name, type: accountTypeFor(name, prefixes));
  }

  static List<String> _splitList(String text) => <String>[
    for (final String item in text.split(RegExp(r'[,\s]+')))
      if (item.trim().isNotEmpty) item.trim(),
  ];

  bool get _fieldsValid {
    if (_parseDate(_date.text) == null) return false;
    if (_legs.length < 2) return false;
    for (final _LegDraft leg in _legs) {
      if (leg.account == null) return false;
      if (_number(leg.number) == null && leg.number.trim().isNotEmpty) return false;
      if (_number(leg.costNumber) == null && leg.costNumber.trim().isNotEmpty) return false;
      if (_number(leg.priceNumber) == null && leg.priceNumber.trim().isNotEmpty) return false;
      if (_currency(leg.currency) == null && leg.currency.trim().isNotEmpty) return false;
      if (_currency(leg.costCurrency) == null && leg.costCurrency.trim().isNotEmpty) return false;
      if (_currency(leg.priceCurrency) == null && leg.priceCurrency.trim().isNotEmpty) return false;
    }
    if (!_advanced) {
      return _number(_legs[0].number) != null && _currency(_legs[0].currency) != null;
    }
    return true;
  }

  void _queueCheck() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _check);
  }

  Future<void> _check() async {
    final TransactionDraft? draft = _draft();
    if (draft == null || !_fieldsValid) {
      if (mounted) setState(() => _errors = const <String>[]);
      return;
    }
    final String target = _target ?? widget.session.document?.displayName ?? '';
    final List<String> errors = await widget.session.validateTransaction(target, writeTransactionDraft(draft));
    if (mounted) setState(() => _errors = errors);
  }

  bool get _canSave => _draft() != null && _fieldsValid && _errors.isEmpty;

  Future<void> _save() async {
    final TransactionDraft? draft = _draft();
    if (draft == null || !_canSave) return;
    final String target = _target ?? widget.session.document?.displayName ?? '';
    await widget.session.flush();
    await widget.session.addTransaction(target, writeTransactionDraft(draft));
    if (!mounted) return;
    if (widget.session.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.session.error!)));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final List<d.Account> accounts = _eligibleAccounts();
    final List<String> currencies = _ledgerCurrencies();
    return Scaffold(
      appBar: AppBar(title: const Text('New transaction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  key: const Key('date'),
                  controller: _date,
                  decoration: const InputDecoration(labelText: 'Date'),
                  onChanged: (String _) {
                    setState(_defaultAccounts);
                    _queueCheck();
                  },
                ),
              ),
              if (_advanced) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<d.SpecialFlag>(
                    key: const Key('flag'),
                    initialValue: _flag,
                    decoration: const InputDecoration(labelText: 'Flag'),
                    items: <DropdownMenuItem<d.SpecialFlag>>[
                      for (final d.SpecialFlag flag in d.SpecialFlag.values)
                        DropdownMenuItem<d.SpecialFlag>(value: flag, child: Text(_flagText(flag))),
                    ],
                    onChanged: (d.SpecialFlag? flag) {
                      if (flag != null) setState(() => _flag = flag);
                    },
                  ),
                ),
              ],
            ],
          ),
          TextFormField(
            key: const Key('payee'),
            controller: _payee,
            decoration: const InputDecoration(labelText: 'Payee'),
            onChanged: (String _) => _queueCheck(),
          ),
          TextFormField(
            key: const Key('narration'),
            controller: _narration,
            decoration: const InputDecoration(labelText: 'Narration'),
            onChanged: (String _) => _queueCheck(),
          ),
          if (_advanced)
            TextFormField(
              key: const Key('tags'),
              controller: _tags,
              decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
              onChanged: (String _) => _queueCheck(),
            ),
          if (_advanced)
            TextFormField(
              key: const Key('links'),
              controller: _links,
              decoration: const InputDecoration(labelText: 'Links (comma separated)'),
              onChanged: (String _) => _queueCheck(),
            ),
          for (int index = 0; index < _legs.length; index++) _legCard(index, accounts, currencies),
          if (_advanced)
            TextButton.icon(
              key: const Key('add-leg'),
              onPressed: () {
                setState(() => _legs.add(_LegDraft()));
                _queueCheck();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add leg'),
            ),
          if (_advanced) ..._metaSection(_meta),
          if (_advanced && _targets().length > 1)
            DropdownButtonFormField<String>(
              key: const Key('target'),
              initialValue: _target ?? _targets().first,
              decoration: const InputDecoration(labelText: 'File'),
              items: <DropdownMenuItem<String>>[
                for (final String target in _targets()) DropdownMenuItem<String>(value: target, child: Text(target)),
              ],
              onChanged: (String? target) {
                if (target != null) {
                  setState(() => _target = target);
                  _queueCheck();
                }
              },
            ),
          for (final String error in _errors)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_unknownAccounts().isNotEmpty) _unopenedPopup(_unknownAccounts().first),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('save'),
            onPressed: _canSave ? _save : null,
            child: const Text('Save transaction'),
          ),
        ],
      ),
    );
  }

  Widget _accountField(int index, _LegDraft leg, List<d.Account> accounts) {
    final String label = index == 0
        ? 'From account'
        : index == _legs.length - 1 && !_advanced
        ? 'To account'
        : 'Account';
    if (_freeAccounts) {
      return TextFormField(
        key: Key('leg-$index-account'),
        controller: TextEditingController(text: leg.accountName),
        decoration: InputDecoration(labelText: label),
        onChanged: (String value) {
          leg
            ..accountName = value
            ..account = _domainAccount(value);
          _queueCheck();
        },
      );
    }
    return DropdownButtonFormField<d.Account>(
      key: Key('leg-$index-account'),
      initialValue: leg.account,
      decoration: InputDecoration(labelText: label),
      items: <DropdownMenuItem<d.Account>>[
        for (final d.Account account in accounts)
          if (account == leg.account || !_legs.any((_LegDraft other) => other.account == account))
            DropdownMenuItem<d.Account>(value: account, child: Text(account.name)),
      ],
      onChanged: (d.Account? account) {
        setState(() => leg.account = account);
        _queueCheck();
      },
    );
  }

  static final RegExp _unknownAccount = RegExp("Invalid reference to unknown account '(.+)'");

  List<String> _unknownAccounts() => <String>[
    for (final String error in _errors)
      if (_unknownAccount.firstMatch(error) case final RegExpMatch match) match.group(1)!,
  ];

  Widget _unopenedPopup(String account) => Card(
    key: const Key('unopened-popup'),
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$account is not opened.', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          const Text('Open the account, or turn a plugin on that opens it.'),
          Row(
            children: <Widget>[
              TextButton(key: const Key('open-account'), onPressed: _openAccount, child: const Text('Open account')),
              TextButton(
                key: const Key('open-plugins'),
                onPressed: () => Navigator.of(context).pop('plugins'),
                child: const Text('Turn a plugin on'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _openAccount() async {
    final String target = _target ?? widget.session.document?.displayName ?? '';
    await widget.session.flush();
    await widget.session.addTransaction(target, '${_today()} open ${_unknownAccounts().first}\n');
    if (!mounted) return;
    if (widget.session.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.session.error!)));
    }
  }

  List<String> _ledgerCurrencies() => switch (widget.session.snapshot?.booked.ledger) {
    d.LedgerDirectives(:final d.ProcessingInfo info) => <String>[
      for (final d.Currency currency in info.commodities) currency.name,
    ],
    _ => const <String>[],
  };

  Widget _legCard(int index, List<d.Account> accounts, List<String> currencies) {
    final _LegDraft leg = _legs[index];
    final bool amountField = _advanced || index == 0;
    return Card(
      key: Key('leg-$index'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _accountField(index, leg, accounts)),
                if (_advanced && _legs.length > 2)
                  IconButton(
                    key: Key('leg-$index-remove'),
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _legs.removeAt(index));
                      _queueCheck();
                    },
                  ),
              ],
            ),
            if (amountField)
              TextFormField(
                key: Key('leg-$index-number'),
                controller: TextEditingController(text: leg.number),
                decoration: const InputDecoration(labelText: 'Amount'),
                onChanged: (String value) {
                  leg.number = value;
                  _queueCheck();
                },
              ),
            if (amountField)
              TextFormField(
                key: Key('leg-$index-currency'),
                controller: TextEditingController(text: leg.currency),
                decoration: const InputDecoration(labelText: 'Currency'),
                onChanged: (String value) {
                  leg.currency = value;
                  _queueCheck();
                },
              ),
            if (_advanced && currencies.isNotEmpty)
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final String currency in currencies.take(6))
                    ActionChip(
                      label: Text(currency),
                      onPressed: () {
                        setState(() => leg.currency = currency);
                        _queueCheck();
                      },
                    ),
                ],
              ),
            if (_advanced) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      key: Key('leg-$index-cost'),
                      controller: TextEditingController(text: leg.costNumber),
                      decoration: InputDecoration(labelText: leg.costTotal ? 'Cost total' : 'Cost per unit'),
                      onChanged: (String value) {
                        leg.costNumber = value;
                        _queueCheck();
                      },
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      key: Key('leg-$index-cost-currency'),
                      controller: TextEditingController(text: leg.costCurrency),
                      decoration: const InputDecoration(labelText: 'Cost currency'),
                      onChanged: (String value) {
                        leg.costCurrency = value;
                        _queueCheck();
                      },
                    ),
                  ),
                  Switch(
                    key: Key('leg-$index-cost-total'),
                    value: leg.costTotal,
                    onChanged: (bool total) {
                      setState(() => leg.costTotal = total);
                      _queueCheck();
                    },
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      key: Key('leg-$index-price'),
                      controller: TextEditingController(text: leg.priceNumber),
                      decoration: InputDecoration(labelText: leg.priceTotal ? 'Total price' : 'Price per unit'),
                      onChanged: (String value) {
                        leg.priceNumber = value;
                        _queueCheck();
                      },
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      key: Key('leg-$index-price-currency'),
                      controller: TextEditingController(text: leg.priceCurrency),
                      decoration: const InputDecoration(labelText: 'Price currency'),
                      onChanged: (String value) {
                        leg.priceCurrency = value;
                        _queueCheck();
                      },
                    ),
                  ),
                  Switch(
                    key: Key('leg-$index-price-total'),
                    value: leg.priceTotal,
                    onChanged: (bool total) {
                      setState(() => leg.priceTotal = total);
                      _queueCheck();
                    },
                  ),
                ],
              ),
              ..._metaSection(leg.meta),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _metaSection(List<_MetaDraft> rows) => <Widget>[
    Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: <Widget>[
          const Text('Metadata'),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() => rows.add(_MetaDraft()));
              _queueCheck();
            },
          ),
        ],
      ),
    ),
    for (int index = 0; index < rows.length; index++)
      Row(
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: TextEditingController(text: rows[index].key),
              decoration: const InputDecoration(labelText: 'Key'),
              onChanged: (String value) {
                rows[index].key = value;
                _queueCheck();
              },
            ),
          ),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: rows[index].type,
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
                  setState(() => rows[index].type = type);
                  _queueCheck();
                }
              },
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: TextEditingController(text: rows[index].value),
              decoration: const InputDecoration(labelText: 'Value'),
              onChanged: (String value) {
                rows[index].value = value;
                _queueCheck();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() => rows.removeAt(index));
              _queueCheck();
            },
          ),
        ],
      ),
  ];
}

String _flagText(d.SpecialFlag flag) => switch (flag) {
  d.SpecialFlag.asterisk => '*',
  d.SpecialFlag.exclamation => '!',
  d.SpecialFlag.hash => '#',
  d.SpecialFlag.ampersand => '&',
  d.SpecialFlag.question => '?',
  d.SpecialFlag.percent => '%',
};
