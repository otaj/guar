// Parser copies of date compare and insert-route helpers must match guar_domain.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  String extractFunction(String path, String name) {
    final source = File(path).readAsStringSync();
    final marker = '$name(';
    var from = 0;
    while (true) {
      final at = source.indexOf(marker, from);
      if (at < 0) {
        throw StateError('$name not found in $path');
      }
      final before = at == 0 ? '\n' : source[at - 1];
      if (RegExp(r'[A-Za-z0-9_]').hasMatch(before)) {
        from = at + marker.length;
        continue;
      }
      var parenDepth = 0;
      var i = at + name.length;
      for (; i < source.length; i++) {
        final ch = source[i];
        if (ch == '(') {
          parenDepth += 1;
        } else if (ch == ')') {
          parenDepth -= 1;
          if (parenDepth == 0) {
            i += 1;
            break;
          }
        }
      }
      while (i < source.length && (source[i] == ' ' || source[i] == '\n')) {
        i += 1;
      }
      if (i >= source.length || source[i] != '{') {
        from = at + marker.length;
        continue;
      }
      final open = i;
      var depth = 0;
      for (var i = open; i < source.length; i++) {
        final ch = source[i];
        if (ch == '{') {
          depth += 1;
        } else if (ch == '}') {
          depth -= 1;
          if (depth == 0) {
            final lineStart = source.lastIndexOf('\n', at) + 1;
            return source.substring(lineStart, i + 1);
          }
        }
      }
      throw StateError('$name is unclosed in $path');
    }
  }

  const parserDate = 'lib/src/domain/date.dart';
  const domainDate = '../guar_domain/lib/src/date.dart';
  const parserRoute = 'lib/src/parser/insert_route.dart';
  const domainRoute = '../guar_domain/lib/src/insert_route.dart';

  test('compareBeanDate stays in lockstep with guar_domain', () {
    expect(extractFunction(parserDate, 'compareBeanDate'), extractFunction(domainDate, 'compareBeanDate'));
  });

  test('optionPluginLocation stays in lockstep with guar_domain', () {
    expect(extractFunction(parserRoute, 'optionPluginLocation'), extractFunction(domainRoute, 'optionPluginLocation'));
  });

  test('insert path helpers stay in lockstep with guar_domain', () {
    expect(extractFunction(parserRoute, '_resolveAgainst'), extractFunction(domainRoute, '_resolveAgainst'));
    expect(extractFunction(parserRoute, '_treeMember'), extractFunction(domainRoute, '_treeMember'));
  });

  test('account extraction stays in lockstep aside from booked-only budget bodies', () {
    const budgetArms =
        '    DocumentBody(:final account) ||\n'
        '    BudgetBody(:final account) ||\n'
        '    BudgetOffBody(:final account) => [account.name],\n';
    const parserArms = '    DocumentBody(:final account) => [account.name],\n';
    expect(
      extractFunction(parserRoute, '_accountsForInsert'),
      extractFunction(domainRoute, '_accountsForInsert').replaceAll(budgetArms, parserArms),
    );
  });
}
