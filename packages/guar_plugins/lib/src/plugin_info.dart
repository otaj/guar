// Description and configuration shape for one registered booking plugin.

import 'package:decimal/decimal.dart';
import 'package:guar_plugins/src/plugin.dart';

typedef PluginDecode = PluginStored Function(String? config);

typedef PluginEncode = PluginWrite Function(PluginStored stored);

const String pluginQuoteError = 'Quotes cannot be stored in a plugin configuration';

const String pluginLineError = 'A plugin configuration has to fit on one line';

class PluginDeclaration {
  const PluginDeclaration({required this.name, required this.description, required this.apply, this.setup});

  final String name;
  final String description;
  final BookPlugin apply;
  final PluginSetup? setup;
}

class PluginSetup {
  const PluginSetup({required this.fields, required this.decode, required this.encode});

  final List<PluginField> fields;
  final PluginDecode decode;
  final PluginEncode encode;
}

sealed class PluginField {
  const PluginField({required this.id, required this.label, this.hint = ''});

  final String id;
  final String label;
  final String hint;
}

class PluginTextField extends PluginField {
  const PluginTextField({required super.id, required super.label, super.hint});
}

class PluginDecimalField extends PluginField {
  const PluginDecimalField({required super.id, required super.label, super.hint});
}

class PluginFlagField extends PluginField {
  const PluginFlagField({required super.id, required super.label, super.hint});
}

enum PluginColumnKind { text, decimal, integer }

class PluginColumn {
  const PluginColumn(this.label, {this.kind = PluginColumnKind.text});

  final String label;
  final PluginColumnKind kind;
}

class PluginTableField extends PluginField {
  const PluginTableField({required super.id, required super.label, required this.columns, super.hint});

  final List<PluginColumn> columns;
}

sealed class PluginCell {
  const PluginCell();
}

class PluginTextCell extends PluginCell {
  const PluginTextCell(this.value);

  final String value;
}

class PluginDecimalCell extends PluginCell {
  const PluginDecimalCell([this.value]);

  final Decimal? value;
}

class PluginIntCell extends PluginCell {
  const PluginIntCell([this.value]);

  final int? value;
}

class PluginRulesField extends PluginField {
  const PluginRulesField({required super.id, required super.label, super.hint});
}

class PluginInsert {
  const PluginInsert({required this.account, required this.currencies});

  final String account;
  final String currencies;
}

class PluginRule {
  const PluginRule({required this.name, required this.pattern, this.inserts = const <PluginInsert>[]});

  final String name;
  final String pattern;
  final List<PluginInsert> inserts;
}

class PluginStored {
  const PluginStored({
    this.text = const <String, String>{},
    this.decimals = const <String, Decimal>{},
    this.flags = const <String, bool>{},
    this.tables = const <String, List<List<PluginCell>>>{},
    this.rules = const <String, List<PluginRule>>{},
    this.raw,
    this.message,
  });

  const PluginStored.unparsed(this.raw, this.message)
    : text = const <String, String>{},
      decimals = const <String, Decimal>{},
      flags = const <String, bool>{},
      tables = const <String, List<List<PluginCell>>>{},
      rules = const <String, List<PluginRule>>{};

  final Map<String, String> text;
  final Map<String, Decimal> decimals;
  final Map<String, bool> flags;
  final Map<String, List<List<PluginCell>>> tables;
  final Map<String, List<PluginRule>> rules;
  final String? raw;
  final String? message;

  bool get structured => raw == null;
}

class PluginWrite {
  const PluginWrite.ok(this.config) : error = null;

  const PluginWrite.bad(this.error) : config = null;

  final String? config;
  final String? error;
}
