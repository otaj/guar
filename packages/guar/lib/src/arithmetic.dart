// Evaluation of the arithmetic expressions the amount fields accept.

import 'package:decimal/decimal.dart';

/// Evaluates simple arithmetic expressions containing `+ - * / ( )` and
/// decimal number literals. Returns null if the expression is invalid.
Decimal? evaluateArithmetic(String input) {
  final List<_Token>? tokens = _tokenize(input);
  if (tokens == null) return null;
  final _Parser parser = _Parser(tokens);
  final Decimal? result = parser.parseExpression();
  if (result == null || !parser.isAtEnd) return null;
  return result;
}

enum _TokenType { number, plus, minus, star, slash, lparen, rparen }

class _Token {
  const _Token(this.type, this.text);

  final _TokenType type;
  final String text;
}

List<_Token>? _tokenize(String input) {
  final List<_Token> tokens = <_Token>[];
  int i = 0;
  while (i < input.length) {
    final String ch = input[i];
    if (ch == ' ' || ch == '\t') {
      i++;
      continue;
    }
    if (ch == '+') {
      tokens.add(const _Token(_TokenType.plus, '+'));
      i++;
    } else if (ch == '-') {
      tokens.add(const _Token(_TokenType.minus, '-'));
      i++;
    } else if (ch == '*') {
      tokens.add(const _Token(_TokenType.star, '*'));
      i++;
    } else if (ch == '/') {
      tokens.add(const _Token(_TokenType.slash, '/'));
      i++;
    } else if (ch == '(') {
      tokens.add(const _Token(_TokenType.lparen, '('));
      i++;
    } else if (ch == ')') {
      tokens.add(const _Token(_TokenType.rparen, ')'));
      i++;
    } else if (_isDigit(ch) || ch == '.') {
      final int start = i;
      while (i < input.length && (_isDigit(input[i]) || input[i] == '.')) {
        i++;
      }
      tokens.add(_Token(_TokenType.number, input.substring(start, i)));
    } else {
      return null;
    }
  }
  return tokens;
}

bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;

// Grammar:
//   expression := term (('+' | '-') term)*
//   term       := unary (('*' | '/') unary)*
//   unary      := '-' unary | atom
//   atom       := NUMBER | '(' expression ')'
class _Parser {
  _Parser(this._tokens);

  final List<_Token> _tokens;
  int _pos = 0;
  bool get isAtEnd => _pos >= _tokens.length;

  _Token? _peek() => _pos < _tokens.length ? _tokens[_pos] : null;

  _Token? _advance() {
    if (_pos < _tokens.length) {
      return _tokens[_pos++];
    }
    return null;
  }

  bool _match(_TokenType type) {
    if (_peek()?.type == type) {
      _pos++;
      return true;
    }
    return false;
  }

  Decimal? parseExpression() {
    final Decimal? first = _parseTerm();
    if (first == null) return null;
    Decimal left = first;
    while (true) {
      if (_match(_TokenType.plus)) {
        final Decimal? right = _parseTerm();
        if (right == null) return null;
        left = left + right;
      } else if (_match(_TokenType.minus)) {
        final Decimal? right = _parseTerm();
        if (right == null) return null;
        left = left - right;
      } else {
        break;
      }
    }
    return left;
  }

  Decimal? _parseTerm() {
    final Decimal? first = _parseUnary();
    if (first == null) return null;
    Decimal left = first;
    while (true) {
      if (_match(_TokenType.star)) {
        final Decimal? right = _parseUnary();
        if (right == null) return null;
        left = left * right;
      } else if (_match(_TokenType.slash)) {
        final Decimal? right = _parseUnary();
        if (right == null) return null;
        if (right == Decimal.zero) return null;
        left = (left / right).toDecimal(scaleOnInfinitePrecision: 10);
      } else {
        break;
      }
    }
    return left;
  }

  Decimal? _parseUnary() {
    if (_match(_TokenType.minus)) {
      final Decimal? operand = _parseUnary();
      if (operand == null) return null;
      return -operand;
    }
    if (_match(_TokenType.plus)) {
      return _parseUnary();
    }
    return _parseAtom();
  }

  Decimal? _parseAtom() {
    final _Token? token = _peek();
    if (token == null) return null;
    if (token.type == _TokenType.number) {
      _advance();
      return Decimal.tryParse(token.text);
    }
    if (token.type == _TokenType.lparen) {
      _advance();
      final Decimal? expr = parseExpression();
      if (expr == null) return null;
      if (!_match(_TokenType.rparen)) return null;
      return expr;
    }
    return null;
  }
}
