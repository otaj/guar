// Renders a parsed transaction directive into beancount source, keeping elided legs elided.

import 'package:guar_parser/guar_parser.dart' as p;

String writeTransaction(p.ParsedDirective directive) {
  final p.ParsedTransaction transaction = switch (directive.body) {
    p.TransactionBody(:final p.ParsedTransaction value) => value,
    _ => throw ArgumentError('Not a transaction directive'),
  };
  final StringBuffer out = StringBuffer('${directive.date} ${_flag(transaction.flag)} ');
  final String? payee = transaction.payee;
  if (payee != null) out.write('${_quote(payee)} ');
  out.write(_quote(transaction.narration));
  for (final p.Tag tag in transaction.tags) {
    out.write(' #${tag.name}');
  }
  for (final p.Link link in transaction.links) {
    out.write(' ^${link.name}');
  }
  out.write('\n');
  for (final p.MetaEntry entry in directive.meta.entries) {
    out.write('  ${_metaEntry(entry)}\n');
  }
  for (final p.ParsedPosting posting in transaction.postings) {
    out.write(_posting(posting));
  }
  return out.toString();
}

String _posting(p.ParsedPosting posting) {
  final String flag = _flag(posting.flag);
  final String account = posting.account.name;
  final String? units = _units(posting.units);
  final String? cost = _cost(posting.cost);
  final String? price = _price(posting.price);
  final String amounts = <String>[?units, ?cost, ?price].join(' ');
  final String prefix = flag.isEmpty ? '' : '$flag ';
  final String line = amounts.isEmpty ? '$prefix$account' : '$prefix$account  $amounts';
  final StringBuffer out = StringBuffer('  $line\n');
  for (final p.MetaEntry entry in posting.meta.entries) {
    out.write('  ${_metaEntry(entry)}\n');
  }
  return out.toString();
}

String _flag(p.Flag? flag) {
  final p.Flag? value = flag;
  if (value == null) return '';
  return switch (value) {
    p.SpecialFlagValue(:final p.SpecialFlag value) => switch (value) {
      p.SpecialFlag.asterisk => '*',
      p.SpecialFlag.exclamation => '!',
      p.SpecialFlag.hash => '#',
      p.SpecialFlag.ampersand => '&',
      p.SpecialFlag.question => '?',
      p.SpecialFlag.percent => '%',
    },
    p.LetterFlag(:final String value) => value,
  };
}

String? _units(p.IncompleteAmount? units) {
  final p.IncompleteAmount? value = units;
  if (value == null) return null;
  final String? number = value.number?.verbatim;
  final String? currency = value.currency?.name;
  if (number == null && currency == null) return null;
  return <String>[?number, ?currency].join(' ');
}

String? _cost(p.ParsedCost? cost) {
  final p.ParsedCost? value = cost;
  if (value == null) return null;
  final bool isTotal = value.numberTotal != null && value.numberPer == null;
  final String open = isTotal ? '{{' : '{';
  final String close = isTotal ? '}}' : '}';
  final String amount = <String>[
    if (value.numberPer != null) ?value.numberPer?.verbatim,
    if (value.numberTotal != null) ...<String>[?value.numberPer == null ? null : '#', value.numberTotal!.verbatim],
    ?value.currency?.name,
  ].join(' ');
  final List<String> parts = <String>[
    if (amount.isNotEmpty) amount,
    ?value.date?.$date,
    ?value.label == null ? null : _quote(value.label!),
    if (value.merge) '*',
  ];
  return '$open${parts.join(', ')}$close';
}

String? _price(p.ParsedPrice? price) {
  final p.ParsedPrice? value = price;
  if (value == null) return null;
  final String? number = value.number?.verbatim;
  final String? currency = value.currency?.name;
  if (number == null && currency == null) return null;
  return '${value.isTotal ? '@@' : '@'} ${<String>[?number, ?currency].join(' ')}';
}

String _metaEntry(p.MetaEntry entry) {
  final p.MetaValue? value = entry.value;
  if (value == null) return '${entry.key}:';
  final String rendered = switch (value) {
    p.MetaText(:final String value) => _quote(value),
    p.MetaAccount(:final p.Account value) => value.name,
    p.MetaCurrency(:final p.Currency value) => value.name,
    p.MetaTag(:final p.Tag value) => '#${value.name}',
    p.MetaDate(:final p.BeanDate value) => '$value',
    p.MetaBoolean(:final bool value) => value ? 'TRUE' : 'FALSE',
    p.MetaNumber(:final p.BeanNumber value) => value.verbatim,
    p.MetaAmount(:final p.Amount value) => '${value.number.verbatim} ${value.currency.name}',
  };
  return '${entry.key}: $rendered';
}

String _quote(String value) {
  if (value.contains('"')) {
    throw const FormatException('Beancount strings cannot contain a double quote');
  }
  return '"$value"';
}

extension on p.BeanDate {
  String get $date => '$this';
}
