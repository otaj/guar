// Stand-in for Python's eval() on stock plugin configuration strings.

typedef ConfigLiteral = ({Object? value, String? error});

ConfigLiteral parseConfigLiteral(String source) {
  final _LiteralParser parser = _LiteralParser(source);
  try {
    parser._skipSpace();
    final Object? value = parser._value();
    parser._skipSpace();
    if (!parser._atEnd) {
      return (value: null, error: 'Unexpected trailing input at offset ${parser._offset}');
    }
    return (value: value, error: null);
  } on FormatException catch (error) {
    return (value: null, error: error.message);
  }
}

class _LiteralParser {
  _LiteralParser(this._source);

  final String _source;
  int _offset = 0;

  bool get _atEnd => _offset >= _source.length;

  String get _current => _source[_offset];

  void _skipSpace() {
    while (!_atEnd && (_current == ' ' || _current == '\t' || _current == '\n' || _current == '\r')) {
      _offset++;
    }
  }

  Never _fail(String message) => throw FormatException(message);

  Object? _value() {
    if (_atEnd) _fail('Unexpected end of configuration');
    switch (_current) {
      case '{':
        return _dict();
      case '[':
        return _list();
      case '(':
        return _tuple();
      case "'":
      case '"':
        return _string();
    }
    if (_literal('None')) return null;
    if (_literal('True')) return true;
    if (_literal('False')) return false;
    return _number();
  }

  bool _literal(String word) {
    if (!_source.startsWith(word, _offset)) return false;
    _offset += word.length;
    return true;
  }

  Map<Object?, Object?> _dict() {
    _offset++;
    final Map<Object?, Object?> map = <Object?, Object?>{};
    _skipSpace();
    while (!_atEnd && _current != '}') {
      final Object? key = _value();
      _skipSpace();
      if (_atEnd || _current != ':') _fail('Expected ":" in dict at offset $_offset');
      _offset++;
      _skipSpace();
      map[key] = _value();
      _skipSpace();
      if (!_atEnd && _current == ',') {
        _offset++;
        _skipSpace();
      }
    }
    if (_atEnd) _fail('Unterminated dict');
    _offset++;
    return map;
  }

  List<Object?> _list() => _sequence('[', ']');

  List<Object?> _tuple() => _sequence('(', ')');

  List<Object?> _sequence(String open, String close) {
    _offset++;
    final List<Object?> items = <Object?>[];
    _skipSpace();
    while (!_atEnd && _current != close) {
      items.add(_value());
      _skipSpace();
      if (!_atEnd && _current == ',') {
        _offset++;
        _skipSpace();
      }
    }
    if (_atEnd) _fail('Unterminated "$open"');
    _offset++;
    return items;
  }

  String _string() {
    final String quote = _current;
    _offset++;
    final StringBuffer buffer = StringBuffer();
    while (!_atEnd && _current != quote) {
      if (_current == r'\') {
        _offset++;
        if (_atEnd) _fail('Unterminated escape in string');
        buffer.write(switch (_current) {
          'n' => '\n',
          't' => '\t',
          'r' => '\r',
          _ => _current,
        });
        _offset++;
        continue;
      }
      buffer.write(_current);
      _offset++;
    }
    if (_atEnd) _fail('Unterminated string');
    _offset++;
    return buffer.toString();
  }

  num _number() {
    final int start = _offset;
    if (!_atEnd && (_current == '-' || _current == '+')) _offset++;
    bool digits = false;
    bool fractional = false;
    while (!_atEnd) {
      final String char = _current;
      if (char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39) {
        digits = true;
        _offset++;
      } else if (char == '.' && !fractional) {
        fractional = true;
        _offset++;
      } else if (char == 'e' || char == 'E') {
        fractional = true;
        _offset++;
        if (!_atEnd && (_current == '-' || _current == '+')) _offset++;
      } else {
        break;
      }
    }
    if (!digits) _fail('Unexpected character "${_source[start]}" at offset $start');
    final String text = _source.substring(start, _offset);
    return fractional ? double.parse(text) : int.parse(text);
  }
}
