// Cover the Python-literal subset accepted by plugin configuration strings.

import 'package:guar_book/src/plugins/config_literal.dart';
import 'package:test/test.dart';

void main() {
  test('parses scalars', () {
    expect(parseConfigLiteral('None').value, isNull);
    expect(parseConfigLiteral('True').value, isTrue);
    expect(parseConfigLiteral('False').value, isFalse);
    expect(parseConfigLiteral('1').value, 1);
    expect(parseConfigLiteral('-0.5').value, -0.5);
    expect(parseConfigLiteral('1e-2').value, 0.01);
    expect(parseConfigLiteral("'single'").value, 'single');
    expect(parseConfigLiteral('"double"').value, 'double');
    expect(parseConfigLiteral(r"'it\'s'").value, "it's");
  });

  test('parses lists and nested dicts', () {
    expect(parseConfigLiteral("['a', 'b',]").value, ['a', 'b']);
    expect(parseConfigLiteral("{'sector': ['Tech'], 'name': None}").value, {
      'sector': ['Tech'],
      'name': null,
    });
  });

  test('tolerates the whitespace of a multi-line configuration', () {
    expect(parseConfigLiteral("{\n  'strategy': ['bigtech', 'bonds'],\n}").value, {
      'strategy': ['bigtech', 'bonds'],
    });
  });

  test('reports malformed input', () {
    expect(parseConfigLiteral("{'a': }").error, isNotNull);
    expect(parseConfigLiteral("['a'").error, isNotNull);
    expect(parseConfigLiteral('1 2').error, isNotNull);
    expect(parseConfigLiteral('').error, isNotNull);
  });
}
