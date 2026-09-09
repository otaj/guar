// Line-oriented Beancount document parser built on petitparser fragments.

import 'package:petitparser/petitparser.dart';

import '../domain/domain.dart';
import 'tokens.dart';

class BeancountGrammar {
  BeancountGrammar({this.filename = ''});

  final String filename;

  ParsedLedger parse(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final directives = <ParsedDirective>[];
    var index = 0;
    while (index < lines.length) {
      final raw = lines[index];
      final lineNo = index + 1;
      index += 1;
      final code = _stripTrailingComment(raw).trimRight();
      if (code.trim().isEmpty) {
        continue;
      }
      if (code.trimLeft().startsWith(';')) {
        continue;
      }
      if (code.startsWith(' ') || code.startsWith('\t')) {
        return ParsedLedger.errors(
          errors: [
            ParseError(
              message: _foundExpected(code.trimLeft(), 0),
              location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo),
            ),
          ],
          info: _info(),
        );
      }
      final header = _parseDirectiveHeader(code, lineNo);
      if (header == null) {
        return ParsedLedger.errors(
          errors: [
            ParseError(
              message: _foundExpected(code, _directiveFailurePosition(code)),
              location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo),
            ),
          ],
          info: _info(),
        );
      }
      if (header.body is TransactionBody) {
        final postings = <ParsedPosting>[];
        final txn = (header.body as TransactionBody).value;
        final tags = [...txn.tags];
        final links = [...txn.links];
        ParsedPosting? lastPosting;
        var endLine = lineNo;
        while (index < lines.length) {
          final postingRaw = lines[index];
          if (postingRaw.trimLeft().startsWith(';')) {
            index += 1;
            continue;
          }
          final postingCode = _stripTrailingComment(postingRaw).trimRight();
          if (postingCode.trim().isEmpty) {
            break;
          }
          if (!(postingCode.startsWith(' ') || postingCode.startsWith('\t'))) {
            break;
          }
          final postingLine = index + 1;
          final trimmed = postingCode.trimLeft();
          final tagsLinks = _parseTagsLinksLine(trimmed);
          if (tagsLinks != null) {
            if (lastPosting != null) {
              return ParsedLedger.errors(
                errors: [
                  ParseError(
                    message: _foundExpected(trimmed, 0),
                    location: BeanLocation(filename: filename, linenoBegin: postingLine, linenoEnd: postingLine),
                  ),
                ],
                info: _info(),
              );
            }
            tags.addAll(tagsLinks.tags);
            links.addAll(tagsLinks.links);
            endLine = postingLine;
            index += 1;
            continue;
          }
          final posting = _parsePosting(trimmed, postingLine);
          if (posting == null) {
            return ParsedLedger.errors(
              errors: [
                ParseError(
                  message: _foundExpected(trimmed, _postingFailurePosition(trimmed)),
                  location: BeanLocation(filename: filename, linenoBegin: postingLine, linenoEnd: postingLine),
                ),
              ],
              info: _info(),
            );
          }
          postings.add(posting);
          lastPosting = posting;
          endLine = postingLine;
          index += 1;
        }
        directives.add(
          header.copyWith(
            location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: endLine),
            body: DirectiveBody.transaction(txn.copyWith(tags: tags, links: links, postings: postings)),
          ),
        );
      } else {
        directives.add(header);
      }
    }
    directives.sort(_compareDirectives);
    return ParsedLedger.directives(directives: directives, info: _info());
  }

  ProcessingInfo _info() => ProcessingInfo(filename: filename.isEmpty ? null : filename);

  String _stripTrailingComment(String line) {
    final inString = false;
    // Strings are rare on comment-bearing lines; strip ; outside quotes.
    var quoted = inString;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        quoted = !quoted;
      } else if (ch == ';' && !quoted) {
        return line.substring(0, i);
      }
    }
    return line;
  }

  ParsedDirective? _parseDirectiveHeader(String line, int lineNo) {
    final location = BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo);
    final open = (date() & spaces() & string('open') & spaces() & account() & _openTail()).map((values) {
      final tail = values[5] as ({List<Currency> currencies, BookingMethod? booking});
      return ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.open(account: values[4] as Account, currencies: tail.currencies, booking: tail.booking),
      );
    });
    final close = (date() & spaces() & string('close') & spaces() & account()).map((values) {
      return ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.close(account: values[4] as Account),
      );
    });
    final commodity = (date() & spaces() & string('commodity') & spaces() & currency()).map((values) {
      return ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.commodity(currency: values[4] as Currency),
      );
    });
    final transaction = (date() & spaces() & flag() & _txnTail()).map((values) {
      final tail = values[3] as ({String? payee, String narration, List<Tag> tags, List<Link> links});
      return ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.transaction(
          ParsedTransaction(
            flag: values[2] as Flag,
            payee: tail.payee,
            narration: tail.narration,
            tags: tail.tags,
            links: tail.links,
          ),
        ),
      );
    });
    final balance = (date() & spaces() & string('balance') & spaces() & account() & spaces() & _balanceAmount()).map((
      values,
    ) {
      final amountTol = values[6] as ({Amount amount, BeanNumber? tolerance});
      return ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.balance(
          account: values[4] as Account,
          amount: amountTol.amount,
          tolerance: amountTol.tolerance,
        ),
      );
    });
    final pad = (date() & spaces() & string('pad') & spaces() & account() & spaces() & account()).map((values) {
      return ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.pad(account: values[4] as Account, sourceAccount: values[6] as Account),
      );
    });
    final note = (date() & spaces() & string('note') & spaces() & account() & spaces() & quotedString() & _tagsLinks())
        .map((values) {
          final tl = values[7] as ({List<Tag> tags, List<Link> links});
          return ParsedDirective(
            location: location,
            date: values[0] as BeanDate,
            body: DirectiveBody.note(
              account: values[4] as Account,
              comment: values[6] as String,
              tags: tl.tags,
              links: tl.links,
            ),
          );
        });
    final price = (date() & spaces() & string('price') & spaces() & currency() & spaces() & amount()).map((values) {
      return ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.price(currency: values[4] as Currency, amount: values[6] as Amount),
      );
    });
    final event = (date() & spaces() & string('event') & spaces() & quotedString() & spaces() & quotedString()).map((
      values,
    ) {
      return ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.event(name: values[4] as String, description: values[6] as String),
      );
    });
    final query = (date() & spaces() & string('query') & spaces() & quotedString() & spaces() & quotedString()).map((
      values,
    ) {
      return ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.query(name: values[4] as String, queryString: values[6] as String),
      );
    });
    final document =
        (date() & spaces() & string('document') & spaces() & account() & spaces() & quotedString() & _tagsLinks()).map((
          values,
        ) {
          final tl = values[7] as ({List<Tag> tags, List<Link> links});
          return ParsedDirective(
            location: location,
            date: values[0] as BeanDate,
            body: DirectiveBody.document(
              account: values[4] as Account,
              filename: values[6] as String,
              tags: tl.tags,
              links: tl.links,
            ),
          );
        });
    final custom = (date() & spaces() & string('custom') & spaces() & quotedString() & _customValues()).map((values) {
      return ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.custom(type: values[4] as String, values: values[5] as List<CustomValue>),
      );
    });
    final parser =
        (open | close | commodity | balance | pad | note | price | event | query | document | custom | transaction)
            .cast<ParsedDirective>()
            .end();
    final result = parser.parse(line);
    if (result is Failure) {
      _lastFailurePosition = result.position;
      return null;
    }
    return result.value;
  }

  Parser<({Amount amount, BeanNumber? tolerance})> _balanceAmount() {
    final withTolerance = (numberLiteral() & spaces() & char('~') & spaces() & numberLiteral() & spaces() & currency())
        .map((values) {
          return (
            amount: Amount(number: values[0] as BeanNumber, currency: values[6] as Currency),
            tolerance: values[4] as BeanNumber,
          );
        });
    final plain = amount().map((value) => (amount: value, tolerance: null));
    return (withTolerance | plain).cast();
  }

  Parser<({List<Tag> tags, List<Link> links})> _tagsLinks() {
    return (spaces() & _tagOrLink()).star().map((values) {
      final tags = <Tag>[];
      final links = <Link>[];
      for (final part in values) {
        final item = part[1];
        if (item is Tag) {
          tags.add(item);
        } else if (item is Link) {
          links.add(item);
        }
      }
      return (tags: tags, links: links);
    });
  }

  Parser<List<CustomValue>> _customValues() {
    return (spaces() & _customValue()).star().map((values) {
      return [for (final part in values) part[1] as CustomValue];
    });
  }

  Parser<CustomValue> _customValue() {
    final boolean = (string('TRUE').map((_) => true) | string('FALSE').map((_) => false)).cast<bool>().map(
      CustomValue.boolean,
    );
    final dateValue = date().map(CustomValue.date);
    final text = quotedString().map(CustomValue.text);
    final amountValue = amount().map(CustomValue.amount);
    final number = numberLiteral().map(CustomValue.number);
    final accountValue = account().map(CustomValue.account);
    return (boolean | dateValue | text | amountValue | number | accountValue).cast<CustomValue>();
  }

  Parser<({List<Currency> currencies, BookingMethod? booking})> _openTail() {
    final currencies = (spaces() & currency() & (char(',') & spaces().optional() & currency()).star()).map((values) {
      final list = <Currency>[values[1] as Currency];
      for (final part in values[2] as List<dynamic>) {
        list.add((part as List<dynamic>)[2] as Currency);
      }
      return list;
    });
    final booking = (spaces() & quotedString()).map((values) => _bookingMethod(values[1] as String));
    return (currencies.optional().map((value) => value ?? <Currency>[]) & booking.optional()).map((values) {
      return (currencies: values[0] as List<Currency>, booking: values[1] as BookingMethod?);
    });
  }

  BookingMethod? _bookingMethod(String value) {
    return switch (value) {
      'STRICT' => BookingMethod.strict,
      'STRICT_WITH_SIZE' => BookingMethod.strictWithSize,
      'NONE' => BookingMethod.none,
      'AVERAGE' => BookingMethod.average,
      'FIFO' => BookingMethod.fifo,
      'LIFO' => BookingMethod.lifo,
      'HIFO' => BookingMethod.hifo,
      _ => null,
    };
  }

  Parser<({String? payee, String narration, List<Tag> tags, List<Link> links})> _txnTail() {
    final tagsLinks = (spaces() & _tagOrLink()).star().map((values) {
      final tags = <Tag>[];
      final links = <Link>[];
      for (final part in values) {
        final item = part[1];
        if (item is Tag) {
          tags.add(item);
        } else if (item is Link) {
          links.add(item);
        }
      }
      return (tags: tags, links: links);
    });
    final two = (spaces() & quotedString() & spaces() & quotedString() & tagsLinks).map((values) {
      final tl = values[4] as ({List<Tag> tags, List<Link> links});
      return (payee: values[1] as String, narration: values[3] as String, tags: tl.tags, links: tl.links);
    });
    final one = (spaces() & quotedString() & tagsLinks).map((values) {
      final tl = values[2] as ({List<Tag> tags, List<Link> links});
      return (payee: null, narration: values[1] as String, tags: tl.tags, links: tl.links);
    });
    final none = tagsLinks.map((tl) {
      return (payee: null, narration: '', tags: tl.tags, links: tl.links);
    });
    return (two | one | none).cast();
  }

  Parser<Object> _tagOrLink() {
    final name = pattern(r'A-Za-z0-9_./-').plus().flatten();
    final tag = (char('#') & name).map((values) => Tag(name: values[1] as String));
    final link = (char('^') & name).map((values) => Link(name: values[1] as String));
    return (tag | link).cast<Object>();
  }

  ({List<Tag> tags, List<Link> links})? _parseTagsLinksLine(String line) {
    final parser = (_tagOrLink() & (spaces() & _tagOrLink()).star()).end().map((values) {
      final tags = <Tag>[];
      final links = <Link>[];
      void take(Object item) {
        if (item is Tag) {
          tags.add(item);
        } else if (item is Link) {
          links.add(item);
        }
      }

      take(values[0] as Object);
      for (final part in values[1] as List<dynamic>) {
        take((part as List<dynamic>)[1] as Object);
      }
      return (tags: tags, links: links);
    });
    final result = parser.parse(line);
    return result is Success ? result.value : null;
  }

  ParsedPosting? _parsePosting(String line, int lineNo) {
    final location = BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo);
    final parser = (account() & spaces() & units()).end().map((values) {
      return ParsedPosting(location: location, account: values[0] as Account, units: values[2] as IncompleteAmount?);
    });
    final result = parser.parse(line);
    if (result is Failure) {
      _lastFailurePosition = result.position;
      return null;
    }
    return result.value;
  }

  int _lastFailurePosition = 0;

  int _directiveFailurePosition(String line) {
    _parseDirectiveHeader(line, 1);
    return _lastFailurePosition;
  }

  int _postingFailurePosition(String line) {
    _parsePosting(line, 1);
    return _lastFailurePosition;
  }

  String _foundExpected(String input, int position, {String expected = 'something else'}) {
    final found = _foundLexeme(input, position);
    return "found '$found' expected $expected";
  }

  String _foundLexeme(String input, int position) {
    var i = position;
    while (i < input.length && (input.codeUnitAt(i) == 0x20 || input.codeUnitAt(i) == 0x09)) {
      i += 1;
    }
    if (i >= input.length) {
      return '';
    }
    final ch = input[i];
    if (ch == '"') {
      var j = i + 1;
      while (j < input.length && input[j] != '"') {
        if (input[j] == '\\' && j + 1 < input.length) {
          j += 2;
          continue;
        }
        j += 1;
      }
      if (j < input.length) {
        j += 1;
      }
      return input.substring(i, j);
    }
    if ('{}[]()@~,*/'.contains(ch)) {
      return ch;
    }
    var j = i + 1;
    while (j < input.length) {
      final c = input[j];
      if (c == ' ' || c == '\t' || '{}[]()@~,*/"'.contains(c)) {
        break;
      }
      j += 1;
    }
    return input.substring(i, j);
  }

  int _compareDirectives(ParsedDirective a, ParsedDirective b) {
    final byDate = _dateKey(a.date).compareTo(_dateKey(b.date));
    if (byDate != 0) {
      return byDate;
    }
    final byType = _typeOrder(a.body).compareTo(_typeOrder(b.body));
    if (byType != 0) {
      return byType;
    }
    return a.location.linenoBegin.compareTo(b.location.linenoBegin);
  }

  int _dateKey(BeanDate date) => date.year * 10000 + date.month * 100 + date.day;

  int _typeOrder(DirectiveBody body) {
    return switch (body) {
      OpenBody() => 0,
      CloseBody() => 1,
      BalanceBody() => 2,
      PadBody() => 3,
      TransactionBody() => 4,
      NoteBody() => 5,
      DocumentBody() => 6,
      PriceBody() => 7,
      EventBody() => 8,
      QueryBody() => 9,
      CommodityBody() => 10,
      CustomBody() => 11,
    };
  }
}
