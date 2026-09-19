// Parser copies of date compare and insert-route helpers must match guar_domain.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  String extractFunction(String path, String name) {
    final String source = File(path).readAsStringSync();
    final String marker = '$name(';
    int from = 0;
    while (true) {
      final int at = source.indexOf(marker, from);
      if (at < 0) {
        throw StateError('$name not found in $path');
      }
      final String before = at == 0 ? '\n' : source[at - 1];
      if (RegExp('[A-Za-z0-9_]').hasMatch(before)) {
        from = at + marker.length;
        continue;
      }
      int parenDepth = 0;
      int i = at + name.length;
      for (; i < source.length; i++) {
        final String ch = source[i];
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
      final int lineStart = source.lastIndexOf('\n', at) + 1;
      if (i + 1 < source.length && source.substring(i, i + 2) == '=>') {
        i += 2;
        int depth = 0;
        bool started = false;
        for (int j = i; j < source.length; j++) {
          final String ch = source[j];
          if (ch == '{' || ch == '(' || ch == '[') {
            depth += 1;
            started = true;
          } else if (ch == '}' || ch == ')' || ch == ']') {
            depth -= 1;
          } else if (ch == ';' && (!started || depth == 0)) {
            return source.substring(lineStart, j + 1);
          }
        }
        throw StateError('$name is unclosed in $path');
      }
      if (i >= source.length || source[i] != '{') {
        from = at + marker.length;
        continue;
      }
      final int open = i;
      int depth = 0;
      for (int i = open; i < source.length; i++) {
        final String ch = source[i];
        if (ch == '{') {
          depth += 1;
        } else if (ch == '}') {
          depth -= 1;
          if (depth == 0) {
            final int lineStart = source.lastIndexOf('\n', at) + 1;
            return source.substring(lineStart, i + 1);
          }
        }
      }
      throw StateError('$name is unclosed in $path');
    }
  }

  const String parserDate = 'lib/src/domain/date.dart';
  const String domainDate = '../guar_domain/lib/src/date.dart';
  const String parserRoute = 'lib/src/parser/insert_route.dart';
  const String domainRoute = '../guar_domain/lib/src/insert_route.dart';

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
    const String budgetArms =
        '  DocumentBody(:final Account account) ||\n'
        '  BudgetBody(:final Account account) ||\n'
        '  BudgetOffBody(:final Account account) => <String>[account.name],\n';
    const String parserArms = '  DocumentBody(:final Account account) => <String>[account.name],\n';
    expect(
      extractFunction(parserRoute, '_accountsForInsert'),
      extractFunction(domainRoute, '_accountsForInsert')
          .replaceAll(budgetArms, parserArms)
          .replaceAll('Transaction value', 'ParsedTransaction value')
          .replaceAll('Posting posting', 'ParsedPosting posting'),
    );
  });
}
