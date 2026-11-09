// The transaction a screen drafts, mapped from domain types onto parsed directives for rendering.

import 'package:decimal/decimal.dart';
import 'package:guar_book/src/transaction_source.dart';
import 'package:guar_domain/guar_domain.dart' as d;
import 'package:guar_parser/guar_parser.dart' as p;

class TransactionDraft {
  const TransactionDraft({
    required this.date,
    required this.postings,
    this.flag,
    this.payee,
    this.narration = '',
    this.tags = const <d.Tag>[],
    this.links = const <d.Link>[],
    this.meta = const d.Meta(),
  });

  final d.BeanDate date;
  final d.Flag? flag;
  final String? payee;
  final String narration;
  final List<d.Tag> tags;
  final List<d.Link> links;
  final d.Meta meta;
  final List<TransactionDraftPosting> postings;
}

class TransactionDraftPosting {
  const TransactionDraftPosting({
    required this.account,
    this.units,
    this.cost,
    this.price,
    this.meta = const d.Meta(),
  });

  final d.Account account;
  final TransactionDraftAmount? units;
  final TransactionDraftCost? cost;
  final TransactionDraftPrice? price;
  final d.Meta meta;
}

class TransactionDraftAmount {
  const TransactionDraftAmount({this.number, this.currency});

  final Decimal? number;
  final d.Currency? currency;
}

class TransactionDraftCost {
  const TransactionDraftCost({
    this.numberPer,
    this.numberTotal,
    this.currency,
    this.date,
    this.label,
    this.merge = false,
  });

  final Decimal? numberPer;
  final Decimal? numberTotal;
  final d.Currency? currency;
  final d.BeanDate? date;
  final String? label;
  final bool merge;
}

class TransactionDraftPrice {
  const TransactionDraftPrice({this.number, this.currency, this.total = false});

  final Decimal? number;
  final d.Currency? currency;
  final bool total;
}

String writeTransactionDraft(TransactionDraft draft) => writeTransaction(
  p.ParsedDirective(
    location: _location,
    date: _date(draft.date),
    meta: _meta(draft.meta),
    body: p.TransactionBody(
      p.ParsedTransaction(
        flag: _flag(draft.flag),
        payee: draft.payee,
        narration: draft.narration,
        tags: <p.Tag>[for (final d.Tag tag in draft.tags) p.Tag(name: tag.name)],
        links: <p.Link>[for (final d.Link link in draft.links) p.Link(name: link.name)],
        postings: <p.ParsedPosting>[for (final TransactionDraftPosting posting in draft.postings) _posting(posting)],
      ),
    ),
  ),
);

final p.BeanLocation _location = p.BeanLocation(filename: 'guar-draft', linenoBegin: 1, linenoEnd: 1);

p.ParsedPosting _posting(TransactionDraftPosting posting) => p.ParsedPosting(
  location: _location,
  account: p.Account(name: posting.account.name),
  meta: _meta(posting.meta),
  units: _units(posting.units),
  cost: _cost(posting.cost),
  price: _price(posting.price),
);

p.IncompleteAmount? _units(TransactionDraftAmount? units) {
  if (units == null) return null;
  final Decimal? number = units.number;
  final d.Currency? currency = units.currency;
  if (number == null && currency == null) return null;
  return p.IncompleteAmount(
    number: number == null ? null : _number(number),
    currency: currency == null ? null : p.Currency(name: currency.name),
  );
}

p.ParsedCost? _cost(TransactionDraftCost? cost) {
  if (cost == null) return null;
  return p.ParsedCost(
    numberPer: cost.numberPer == null ? null : _number(cost.numberPer!),
    numberTotal: cost.numberTotal == null ? null : _number(cost.numberTotal!),
    currency: cost.currency == null ? null : p.Currency(name: cost.currency!.name),
    date: cost.date == null ? null : _date(cost.date!),
    label: cost.label,
    merge: cost.merge,
  );
}

p.ParsedPrice? _price(TransactionDraftPrice? price) {
  if (price == null) return null;
  return p.ParsedPrice(
    number: price.number == null ? null : _number(price.number!),
    currency: price.currency == null ? null : p.Currency(name: price.currency!.name),
    isTotal: price.total,
  );
}

p.BeanDate _date(d.BeanDate date) => p.BeanDate(year: date.year, month: date.month, day: date.day);

p.BeanNumber _number(Decimal value) => p.BeanNumber(verbatim: value.toString(), resolved: value);

p.Meta _meta(d.Meta meta) => p.Meta(
  entries: <p.MetaEntry>[
    for (final d.MetaEntry entry in meta.entries) p.MetaEntry(key: entry.key, value: _metaValue(entry.value)),
  ],
);

p.MetaValue? _metaValue(d.MetaValue? value) => switch (value) {
  null => null,
  d.MetaText(:final String value) => p.MetaValue.text(value),
  d.MetaAccount(:final d.Account value) => p.MetaValue.account(p.Account(name: value.name)),
  d.MetaCurrency(:final d.Currency value) => p.MetaValue.currency(p.Currency(name: value.name)),
  d.MetaTag(:final d.Tag value) => p.MetaValue.tag(p.Tag(name: value.name)),
  d.MetaDate(:final d.BeanDate value) => p.MetaValue.date(_date(value)),
  d.MetaBoolean(:final bool value) => p.MetaValue.boolean(value),
  d.MetaNumber(:final Decimal value) => p.MetaValue.number(_number(value)),
  d.MetaAmount(:final d.Amount value) => p.MetaValue.amount(
    p.Amount(
      number: _number(value.number),
      currency: p.Currency(name: value.currency.name),
    ),
  ),
};

p.Flag _flag(d.Flag? flag) => switch (flag) {
  null => const p.Flag.special(p.SpecialFlag.asterisk),
  d.SpecialFlagValue(:final d.SpecialFlag value) => p.Flag.special(switch (value) {
    d.SpecialFlag.asterisk => p.SpecialFlag.asterisk,
    d.SpecialFlag.exclamation => p.SpecialFlag.exclamation,
    d.SpecialFlag.hash => p.SpecialFlag.hash,
    d.SpecialFlag.ampersand => p.SpecialFlag.ampersand,
    d.SpecialFlag.question => p.SpecialFlag.question,
    d.SpecialFlag.percent => p.SpecialFlag.percent,
  }),
  d.LetterFlag(:final String value) => p.Flag.letter(value),
};
