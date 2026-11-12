// The transaction editor: simple two-leg entry, or every transaction part in advanced mode.

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guar/src/arithmetic.dart';
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
  String costMode = '';
  String costNumber = '';
  String costCurrency = '';
  String priceMode = '';
  String priceNumber = '';
  String priceCurrency = '';
  String flag = '';
  final List<_MetaDraft> meta = <_MetaDraft>[];
}

class _MetaDraft {
  String key = '';
  String value = '';
  String type = 'text';
}

class _TransactionEditorScreenState extends State<TransactionEditorScreen> {
  d.BeanDate _date = _todayDate();
  final TextEditingController _payee = TextEditingController();
  final TextEditingController _narration = TextEditingController();
  final Set<String> _tags = <String>{};
  final Set<String> _links = <String>{};
  final List<_MetaDraft> _meta = <_MetaDraft>[];
  final List<_LegDraft> _legs = <_LegDraft>[_LegDraft(), _LegDraft()];
  d.Flag _flag = const d.Flag.special(d.SpecialFlag.asterisk);
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
    _payee.dispose();
    _narration.dispose();
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
    final Map<String, d.BeanDate> opens = <String, d.BeanDate>{};
    final Map<String, d.BeanDate> closes = <String, d.BeanDate>{};
    final Map<String, d.Account> accounts = <String, d.Account>{};
    for (final d.Directive directive in _directives()) {
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
        if (d.compareBeanDate(open.value, _date) < 0)
          if (!closes.containsKey(open.key) || d.compareBeanDate(_date, closes[open.key]!) < 0) accounts[open.key]!,
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

  static d.BeanDate _todayDate() {
    final DateTime now = DateTime.now();
    return d.BeanDate(year: now.year, month: now.month, day: now.day);
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

  // Amount fields accept arithmetic; plain decimals keep their typed text.
  String? _resolvedNumber(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (Decimal.tryParse(trimmed) != null) return trimmed;
    final Decimal? evaluated = evaluateArithmetic(trimmed);
    return evaluated?.toString();
  }

  String _negateNumber(String text) {
    final Decimal value = Decimal.tryParse(text)!;
    if (value.compareTo(Decimal.zero) < 0) return text.substring(1);
    if (value == Decimal.zero) return text;
    return '-$text';
  }

  Set<String> _knownTags() => <String>{
    for (final d.Directive directive in _directives())
      if (directive.body case d.TransactionBody(:final d.Transaction value))
        for (final d.Tag tag in value.tags) tag.name,
  };

  Set<String> _knownLinks() => <String>{
    for (final d.Directive directive in _directives())
      if (directive.body case d.TransactionBody(:final d.Transaction value))
        for (final d.Link link in value.links) link.name,
  };

  TransactionDraft? _draft() {
    final String? payee = _payee.text.trim().isEmpty ? null : _payee.text.trim();
    if (payee?.contains('"') ?? false) return null;
    if (_narration.text.contains('"')) return null;
    final List<d.Tag> tags = <d.Tag>[for (final String name in _tags) d.Tag(name: name)];
    final List<d.Link> links = <d.Link>[for (final String name in _links) d.Link(name: name)];
    final d.Meta? meta = _metaOf(_meta);
    if (meta == null) return null;
    final List<TransactionDraftPosting> postings = <TransactionDraftPosting>[];
    if (!_advanced) {
      final String? amount = _resolvedNumber(_legs[0].number);
      final d.Currency? currency = _currency(_legs[0].currency);
      final d.Account? from = _legs[0].account;
      final d.Account? to = _legs[1].account;
      if (amount == null || currency == null || from == null || to == null) return null;
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
        final String? number = _resolvedNumber(leg.number);
        if (leg.number.trim().isNotEmpty && number == null) return null;
        postings.add(
          TransactionDraftPosting(
            account: account,
            units: number == null && unitsCurrency == null
                ? null
                : TransactionDraftAmount(number: number, currency: unitsCurrency),
            cost: cost,
            price: price,
            flag: _flagFromChar(leg.flag),
            meta: legMeta,
          ),
        );
      }
    }
    if (postings.length < 2) return null;
    return TransactionDraft(
      date: _date,
      flag: _flag,
      payee: payee,
      narration: _narration.text.trim(),
      tags: tags,
      links: links,
      meta: meta,
      postings: postings,
    );
  }

  TransactionDraftCost? _costOf(_LegDraft leg) {
    if (leg.costMode.isEmpty) return null;
    final Decimal? number = _number(leg.costNumber);
    final d.Currency? currency = _currency(leg.costCurrency);
    if (leg.costNumber.trim().isNotEmpty && number == null) return null;
    if (leg.costCurrency.trim().isNotEmpty && currency == null) return null;
    if (number == null && currency == null) return null;
    final bool total = leg.costMode == 'total';
    return TransactionDraftCost(
      numberPer: total || leg.costNumber.trim().isEmpty ? null : leg.costNumber.trim(),
      numberTotal: total && leg.costNumber.trim().isNotEmpty ? leg.costNumber.trim() : null,
      currency: currency,
    );
  }

  TransactionDraftPrice? _priceOf(_LegDraft leg) {
    if (leg.priceMode.isEmpty) return null;
    final Decimal? number = _number(leg.priceNumber);
    final d.Currency? currency = _currency(leg.priceCurrency);
    if (leg.priceNumber.trim().isNotEmpty && number == null) return null;
    if (leg.priceCurrency.trim().isNotEmpty && currency == null) return null;
    if (number == null && currency == null) return null;
    return TransactionDraftPrice(
      number: leg.priceNumber.trim().isEmpty ? null : leg.priceNumber.trim(),
      currency: currency,
      total: leg.priceMode == 'total',
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

  bool get _fieldsValid {
    for (final _LegDraft leg in _legs) {
      if (leg.account == null) return false;
      if (leg.number.trim().isNotEmpty && _resolvedNumber(leg.number) == null) return false;
      if (_number(leg.costNumber) == null && leg.costNumber.trim().isNotEmpty) return false;
      if (_number(leg.priceNumber) == null && leg.priceNumber.trim().isNotEmpty) return false;
      if (_currency(leg.currency) == null && leg.currency.trim().isNotEmpty) return false;
      if (_currency(leg.costCurrency) == null && leg.costCurrency.trim().isNotEmpty) return false;
      if (_currency(leg.priceCurrency) == null && leg.priceCurrency.trim().isNotEmpty) return false;
    }
    if (!_advanced) {
      return _resolvedNumber(_legs[0].number) != null && _currency(_legs[0].currency) != null;
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
          _dateTile(),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('narration'),
            controller: _narration,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Description (optional)', prefixIcon: Icon(Icons.description)),
            onChanged: (String _) => _queueCheck(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('payee'),
            controller: _payee,
            decoration: const InputDecoration(labelText: 'Payee (optional)', prefixIcon: Icon(Icons.person)),
            onChanged: (String _) => _queueCheck(),
          ),
          if (_advanced) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Text('Status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                ActionChip(
                  key: const Key('flag'),
                  avatar: const Icon(Icons.flag, size: 16),
                  label: Text(_flagLabel(_flag)),
                  onPressed: _pickFlag,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _tagsSection(),
            const SizedBox(height: 12),
            _linksSection(),
            const SizedBox(height: 12),
            ..._metaSection(_meta, 'Transaction metadata'),
          ],
          if (!_advanced) ...<Widget>[
            const SizedBox(height: 12),
            _basicAmountRow(currencies),
          ],
          const SizedBox(height: 24),
          if (!_advanced) ..._basicAccounts(),
          if (_advanced) ...<Widget>[
            Row(
              children: <Widget>[
                Text('Postings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  key: const Key('add-leg'),
                  onPressed: () {
                    setState(() => _legs.add(_LegDraft()));
                    _queueCheck();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add posting'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (int index = 0; index < _legs.length; index++) _legCard(index, accounts, currencies),
            if (_targets().length > 1)
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
          ],
          for (final String error in _errors)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_unknownAccounts().isNotEmpty) _unopenedPopup(_unknownAccounts().first),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('save'),
            onPressed: _canSave ? _save : null,
            icon: const Icon(Icons.check),
            label: const Text('Add transaction'),
          ),
          if (_advanced)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Leave one posting amount empty for auto-balancing.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(130),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (!_advanced && !_freeAccounts && accounts.length < 2) ...<Widget>[
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You need at least two open accounts to create a transaction. '
                        'Open them with the plus button first.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateTile() {
    final DateTime now = DateTime(_date.year, _date.month, _date.day);
    return ListTile(
      key: const Key('date'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      leading: const Icon(Icons.calendar_today),
      title: Text(_formatDate(_date)),
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked == null) return;
        setState(() {
          _date = d.BeanDate(year: picked.year, month: picked.month, day: picked.day);
        });
        _defaultAccounts();
        _queueCheck();
      },
    );
  }

  Widget _basicAmountRow(List<String> currencies) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        flex: 3,
        child: TextFormField(
          key: const Key('leg-0-number'),
          controller: TextEditingController(text: _legs[0].number),
          decoration: const InputDecoration(labelText: 'Amount', prefixIcon: Icon(Icons.tag, size: 20)),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.+\-*/() ]')),
          ],
          onChanged: (String value) {
            _legs[0].number = value;
            _queueCheck();
          },
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 2,
        child: _CurrencyField(
          fieldKey: const Key('leg-0-currency'),
          initial: _legs[0].currency,
          options: currencies,
          onChanged: (String value) {
            _legs[0].currency = value;
            _queueCheck();
          },
        ),
      ),
    ],
  );

  List<Widget> _basicAccounts() => <Widget>[
    _accountField(0, _legs[0]),
    const SizedBox(height: 4),
    Center(child: Icon(Icons.arrow_downward, color: Theme.of(context).colorScheme.primary, size: 28)),
    const SizedBox(height: 4),
    _accountField(1, _legs[1]),
  ];

  Widget _accountField(int index, _LegDraft leg) {
    final List<d.Account> accounts = _eligibleAccounts();
    final String label = index == 0 ? 'From account' : 'To account';
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
      decoration: const InputDecoration(labelText: 'Account'),
      isExpanded: true,
      items: <DropdownMenuItem<d.Account>>[
        for (final d.Account account in accounts)
          if (account == leg.account || !_legs.any((_LegDraft other) => other.account == account))
            DropdownMenuItem<d.Account>(
              value: account,
              child: Text(account.name, overflow: TextOverflow.ellipsis),
            ),
      ],
      onChanged: (d.Account? account) {
        setState(() => leg.account = account);
        _queueCheck();
      },
    );
  }

  Widget _tagsSection() {
    final Set<String> known = _knownTags()..addAll(_tags);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Tags', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          key: const Key('tags'),
          spacing: 6,
          runSpacing: 4,
          children: <Widget>[
            for (final String tag in <String>[...known]..sort())
              FilterChip(
                label: Text('#$tag'),
                selected: _tags.contains(tag),
                onSelected: (bool selected) {
                  setState(() => selected ? _tags.add(tag) : _tags.remove(tag));
                  _queueCheck();
                },
                visualDensity: VisualDensity.compact,
              ),
            ActionChip(
              key: const Key('add-tag'),
              avatar: Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.primary),
              label: const Text('New tag'),
              onPressed: () => _newNameDialog('#', (String name) => setState(() => _tags.add(name))),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }

  Widget _linksSection() {
    final Set<String> known = _knownLinks()..addAll(_links);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Links', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          key: const Key('links'),
          spacing: 6,
          runSpacing: 4,
          children: <Widget>[
            for (final String link in <String>[...known]..sort())
              FilterChip(
                label: Text('^$link'),
                selected: _links.contains(link),
                onSelected: (bool selected) {
                  setState(() => selected ? _links.add(link) : _links.remove(link));
                  _queueCheck();
                },
                visualDensity: VisualDensity.compact,
              ),
            ActionChip(
              key: const Key('add-link'),
              avatar: Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.primary),
              label: const Text('New link'),
              onPressed: () => _newNameDialog('^', (String name) => setState(() => _links.add(name))),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _newNameDialog(String prefix, void Function(String) onAdd) async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('New ${prefix == '#' ? 'tag' : 'link'}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: 'Name', prefixText: prefix, hintText: 'e.g. trip-2024'),
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-_./]'))],
          onSubmitted: (String value) {
            if (value.trim().isNotEmpty) Navigator.of(dialogContext).pop(value.trim());
          },
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      onAdd(name);
      _queueCheck();
    }
  }

  Future<void> _pickFlag() async {
    final d.Flag? picked = await showModalBottomSheet<d.Flag>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final d.SpecialFlag flag in d.SpecialFlag.values)
              ListTile(
                leading: Text(_specialSymbol(flag), style: Theme.of(context).textTheme.titleMedium),
                title: Text(_specialName(flag)),
                trailing: _flag == d.Flag.special(flag) ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, d.Flag.special(flag)),
              ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Custom flag...'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final d.Flag? flag = await _customFlagDialog();
                if (flag != null) {
                  setState(() => _flag = flag);
                  _queueCheck();
                }
              },
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _flag = picked);
      _queueCheck();
    }
  }

  Future<d.Flag?> _customFlagDialog() async {
    final TextEditingController controller = TextEditingController();
    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Custom Flag'),
        content: TextField(
          controller: controller,
          maxLength: 1,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp('[A-Za-z!&#?%]'))],
          decoration: const InputDecoration(hintText: 'Single character'),
          onSubmitted: (String value) {
            if (value.trim().isNotEmpty) Navigator.of(dialogContext).pop(value.trim());
          },
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (text == null) return null;
    final String ch = text.toUpperCase();
    return _flagFromChar(ch);
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
    await widget.session.addTransaction(target, '$_date open ${_unknownAccounts().first}\n');
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
    final ThemeData theme = Theme.of(context);
    return Card(
      key: Key('leg-$index'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Posting ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: Key('leg-$index-flag'),
                  avatar: Icon(
                    leg.flag.isEmpty ? Icons.flag_outlined : Icons.flag,
                    size: 16,
                    color: leg.flag.isEmpty ? theme.colorScheme.outline : theme.colorScheme.primary,
                  ),
                  label: Text(leg.flag.isEmpty ? 'No flag' : leg.flag, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _pickPostingFlag(leg),
                ),
                const Spacer(),
                if (_legs.length > 2)
                  IconButton(
                    key: Key('leg-$index-remove'),
                    icon: Icon(Icons.close, size: 20, color: theme.colorScheme.error),
                    onPressed: () {
                      setState(() => _legs.removeAt(index));
                      _queueCheck();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _legAccountField(index, leg, accounts),
            const SizedBox(height: 8),
            _legAmountRow(index, leg, currencies),
            const SizedBox(height: 8),
            _priceCostChips(
              mode: leg.priceMode,
              noneLabel: 'No price',
              unitLabel: '@ unit',
              totalLabel: '@@ total',
              onMode: (String mode) {
                setState(() => leg.priceMode = mode);
                _queueCheck();
              },
            ),
            if (leg.priceMode.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _legNumberCurrencyRow(
                numberKey: Key('leg-$index-price'),
                currencyKey: Key('leg-$index-price-currency'),
                number: leg.priceNumber,
                currency: leg.priceCurrency,
                label: leg.priceMode == 'total' ? 'Total price' : 'Price per unit',
                currencies: currencies,
                onNumber: (String value) {
                  leg.priceNumber = value;
                  _queueCheck();
                },
                onCurrency: (String value) {
                  leg.priceCurrency = value;
                  _queueCheck();
                },
              ),
            ],
            const SizedBox(height: 8),
            _priceCostChips(
              mode: leg.costMode,
              noneLabel: 'No cost',
              unitLabel: '{} per unit',
              totalLabel: '{#} total',
              onMode: (String mode) {
                setState(() => leg.costMode = mode);
                _queueCheck();
              },
            ),
            if (leg.costMode.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _legNumberCurrencyRow(
                numberKey: Key('leg-$index-cost'),
                currencyKey: Key('leg-$index-cost-currency'),
                number: leg.costNumber,
                currency: leg.costCurrency,
                label: leg.costMode == 'total' ? 'Total cost' : 'Cost per unit',
                currencies: currencies,
                onNumber: (String value) {
                  leg.costNumber = value;
                  _queueCheck();
                },
                onCurrency: (String value) {
                  leg.costCurrency = value;
                  _queueCheck();
                },
              ),
            ],
            const SizedBox(height: 4),
            ..._metaSection(leg.meta, 'Posting metadata'),
          ],
        ),
      ),
    );
  }

  Widget _legAccountField(int index, _LegDraft leg, List<d.Account> accounts) {
    if (_freeAccounts) {
      return TextFormField(
        key: Key('leg-$index-account'),
        controller: TextEditingController(text: leg.accountName),
        decoration: const InputDecoration(labelText: 'Account'),
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
      decoration: const InputDecoration(labelText: 'Account'),
      isExpanded: true,
      items: <DropdownMenuItem<d.Account>>[
        for (final d.Account account in accounts)
          if (account == leg.account || !_legs.any((_LegDraft other) => other.account == account))
            DropdownMenuItem<d.Account>(
              value: account,
              child: Text(account.name, overflow: TextOverflow.ellipsis),
            ),
      ],
      onChanged: (d.Account? account) {
        setState(() => leg.account = account);
        _queueCheck();
      },
    );
  }

  Widget _legAmountRow(int index, _LegDraft leg, List<String> currencies) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        flex: 3,
        child: TextFormField(
          key: Key('leg-$index-number'),
          controller: TextEditingController(text: leg.number),
          decoration: const InputDecoration(
            labelText: 'Amount',
            hintText: 'Auto',
            prefixIcon: Icon(Icons.tag, size: 20),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.+\-*/() ]')),
          ],
          onChanged: (String value) {
            leg.number = value;
            _queueCheck();
          },
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 2,
        child: _CurrencyField(
          fieldKey: Key('leg-$index-currency'),
          initial: leg.currency,
          options: currencies,
          onChanged: (String value) {
            leg.currency = value;
            _queueCheck();
          },
        ),
      ),
    ],
  );

  Widget _legNumberCurrencyRow({
    required Key numberKey,
    required Key currencyKey,
    required String number,
    required String currency,
    required String label,
    required List<String> currencies,
    required void Function(String) onNumber,
    required void Function(String) onCurrency,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        flex: 3,
        child: TextFormField(
          key: numberKey,
          controller: TextEditingController(text: number),
          decoration: InputDecoration(labelText: label),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp('[0-9.]'))],
          onChanged: onNumber,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 2,
        child: _CurrencyField(
          fieldKey: currencyKey,
          initial: currency,
          options: currencies,
          onChanged: onCurrency,
        ),
      ),
    ],
  );

  Widget _priceCostChips({
    required String mode,
    required String noneLabel,
    required String unitLabel,
    required String totalLabel,
    required void Function(String) onMode,
  }) => Wrap(
    spacing: 6,
    children: <Widget>[
      ChoiceChip(
        label: Text(noneLabel),
        selected: mode.isEmpty,
        onSelected: (_) => onMode(''),
        visualDensity: VisualDensity.compact,
      ),
      ChoiceChip(
        label: Text(unitLabel),
        selected: mode == 'unit',
        onSelected: (_) => onMode('unit'),
        visualDensity: VisualDensity.compact,
      ),
      ChoiceChip(
        label: Text(totalLabel),
        selected: mode == 'total',
        onSelected: (_) => onMode('total'),
        visualDensity: VisualDensity.compact,
      ),
    ],
  );

  Future<void> _pickPostingFlag(_LegDraft leg) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('None'),
              trailing: leg.flag.isEmpty ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
            for (final d.SpecialFlag flag in d.SpecialFlag.values)
              ListTile(
                leading: Text(_specialSymbol(flag), style: Theme.of(context).textTheme.titleMedium),
                title: Text(_specialName(flag)),
                trailing: leg.flag == _specialSymbol(flag) ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, _specialSymbol(flag)),
              ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Custom flag...'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final d.Flag? flag = await _customFlagDialog();
                if (flag != null) {
                  setState(() => leg.flag = _flagLabel(flag));
                  _queueCheck();
                }
              },
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => leg.flag = picked);
    _queueCheck();
  }

  List<Widget> _metaSection(List<_MetaDraft> rows, String title) => <Widget>[
    Row(
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            setState(() => rows.add(_MetaDraft()));
            _queueCheck();
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 12)),
        ),
      ],
    ),
    for (int index = 0; index < rows.length; index++)
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: TextFormField(
                key: Key('meta-$index-key'),
                controller: TextEditingController(text: rows[index].key),
                decoration: const InputDecoration(hintText: 'key', isDense: true),
                onChanged: (String value) {
                  rows[index].key = value;
                  _queueCheck();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(':', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(130))),
            ),
            SizedBox(
              width: 76,
              child: DropdownButtonFormField<String>(
                key: Key('meta-$index-type'),
                initialValue: rows[index].type,
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
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
                    DropdownMenuItem<String>(
                      value: type,
                      child: Text(type, overflow: TextOverflow.ellipsis),
                    ),
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
              flex: 3,
              child: TextFormField(
                key: Key('meta-$index-value'),
                controller: TextEditingController(text: rows[index].value),
                decoration: const InputDecoration(hintText: 'value', isDense: true),
                onChanged: (String value) {
                  rows[index].value = value;
                  _queueCheck();
                },
              ),
            ),
            SizedBox(
              width: 32,
              child: IconButton(
                icon: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.error),
                onPressed: () {
                  setState(() => rows.removeAt(index));
                  _queueCheck();
                },
              ),
            ),
          ],
        ),
      ),
  ];
}

class _CurrencyField extends StatefulWidget {
  const _CurrencyField({
    required this.initial,
    required this.options,
    required this.onChanged,
    this.fieldKey,
  });

  final String initial;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;

  @override
  State<_CurrencyField> createState() => _CurrencyFieldState();
}

class _CurrencyFieldState extends State<_CurrencyField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<String>(
    textEditingController: _controller,
    focusNode: _focus,
    optionsBuilder: (TextEditingValue value) {
      final String query = value.text.trim().toUpperCase();
      if (query.isEmpty) return widget.options;
      return widget.options.where((String option) => option.contains(query)).toList();
    },
    onSelected: (String value) {
      _controller.text = value;
      widget.onChanged(value);
    },
    fieldViewBuilder:
        (
          BuildContext context,
          TextEditingController controller,
          FocusNode focusNode,
          VoidCallback onSubmitted,
        ) => TextFormField(
          key: widget.fieldKey,
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(labelText: 'Currency', isDense: true),
          onChanged: widget.onChanged,
          onFieldSubmitted: (_) => onSubmitted(),
        ),
    optionsViewBuilder:
        (
          BuildContext context,
          AutocompleteOnSelected<String> onSelected,
          Iterable<String> options,
        ) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(dense: true, title: Text(option), onTap: () => onSelected(option));
                },
              ),
            ),
          ),
        ),
  );
}

d.Flag? _flagFromChar(String ch) => switch (ch) {
  '*' => const d.Flag.special(d.SpecialFlag.asterisk),
  '!' => const d.Flag.special(d.SpecialFlag.exclamation),
  '#' => const d.Flag.special(d.SpecialFlag.hash),
  '&' => const d.Flag.special(d.SpecialFlag.ampersand),
  '?' => const d.Flag.special(d.SpecialFlag.question),
  '%' => const d.Flag.special(d.SpecialFlag.percent),
  _ => RegExp(r'^[A-Z]$').hasMatch(ch) ? d.Flag.letter(ch) : null,
};

String _flagLabel(d.Flag flag) => switch (flag) {
  d.SpecialFlagValue(:final d.SpecialFlag value) => _specialSymbol(value),
  d.LetterFlag(:final String value) => value,
};

String _specialSymbol(d.SpecialFlag flag) => switch (flag) {
  d.SpecialFlag.asterisk => '*',
  d.SpecialFlag.exclamation => '!',
  d.SpecialFlag.hash => '#',
  d.SpecialFlag.ampersand => '&',
  d.SpecialFlag.question => '?',
  d.SpecialFlag.percent => '%',
};

String _specialName(d.SpecialFlag flag) => switch (flag) {
  d.SpecialFlag.asterisk => '* (Completed)',
  d.SpecialFlag.exclamation => '! (Incomplete)',
  _ => _specialSymbol(flag),
};

String _formatDate(d.BeanDate date) {
  const List<String> months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  const List<String> weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final int weekday = DateTime(date.year, date.month, date.day).weekday;
  return '${weekdays[weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
}
