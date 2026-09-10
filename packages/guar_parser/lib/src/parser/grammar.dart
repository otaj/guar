// Line-oriented Beancount document parser built on petitparser fragments.

import 'package:petitparser/petitparser.dart';

import '../domain/domain.dart';
import 'include.dart';
import 'option_apply.dart';
import 'tokens.dart';

class BeancountGrammar {
  BeancountGrammar({this.filename = '', this.firstLine = 1, IncludeController? includes})
    : includes = includes ?? IncludeController(readFile: (_) => null);

  final String filename;
  final int firstLine;
  final IncludeController includes;

  ParsedLedger parse(String source, {LedgerOptions? initialOptions}) {
    final state = _ParseState();
    if (initialOptions != null) {
      state.options = initialOptions;
    }
    return _parseInto(source, state, isRoot: true);
  }

  ParsedLedger _parseInto(String source, _ParseState state, {required bool isRoot}) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    ProcessingInfo info() => ProcessingInfo(
      filename: filename.isEmpty ? null : filename,
      include: List.unmodifiable(includes.includeLog),
      plugin: List.unmodifiable(state.plugins),
      optionSettings: List.unmodifiable(state.optionSettings),
    );
    ParsedLedger fail(String message, int lineNo) {
      final error = ParseError(
        message: message,
        location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo),
      );
      state.aborted = true;
      state.errors
        ..clear()
        ..add(error);
      return ParsedLedger.errors(errors: [error], options: state.options, info: info());
    }

    void noteError(String message, int lineNo) {
      state.errors.add(
        ParseError(
          message: message,
          location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo),
        ),
      );
    }

    var index = 0;
    void skipIndentedBlock() {
      while (index < lines.length) {
        final blockRaw = lines[index];
        if (blockRaw.trimLeft().startsWith(';')) {
          index += 1;
          continue;
        }
        final blockCode = _stripTrailingComment(blockRaw).trimRight();
        if (blockCode.trim().isEmpty) {
          index += 1;
          continue;
        }
        if (!(blockCode.startsWith(' ') || blockCode.startsWith('\t'))) {
          break;
        }
        index += 1;
      }
    }

    while (index < lines.length && !state.aborted) {
      final raw = lines[index];
      final lineNo = index + firstLine;
      index += 1;
      var code = _stripTrailingComment(raw).trimRight();
      if (code.trim().isEmpty) {
        continue;
      }
      if (code.trimLeft().startsWith(';')) {
        continue;
      }
      if (_isOrgModeTitle(raw)) {
        continue;
      }
      if (code.startsWith(' ') || code.startsWith('\t')) {
        return fail(_foundExpected(code.trimLeft(), 0), lineNo);
      }
      while (_hasUnclosedQuote(code) && index < lines.length) {
        code = '$code\n${lines[index]}';
        index += 1;
      }
      final includePattern = _parseInclude(code);
      if (includePattern != null) {
        final outcome = includes.open(
          pattern: includePattern,
          fromFilename: filename,
          contextKey: _includeContextKey(state.tagStack, state.metaStack),
        );
        switch (outcome) {
          case IncludeSkip():
            continue;
          case IncludeDuplicate():
            return fail('duplicate include', lineNo);
          case IncludeFailed():
            return fail('include failed', lineNo);
          case IncludeLoaded(:final files):
            for (final hit in files) {
              BeancountGrammar(filename: hit.path, includes: includes)._parseInto(hit.source, state, isRoot: false);
              if (state.aborted) {
                return ParsedLedger.errors(errors: state.errors, options: state.options, info: info());
              }
            }
            continue;
        }
      }
      if (code.startsWith('include')) {
        return fail(_foundExpected(code, _directiveFailurePosition(code)), lineNo);
      }
      final optionPair = _parseOption(code);
      if (optionPair != null) {
        final applied = applyLedgerOption(state.options, optionPair.$1, optionPair.$2);
        if (applied.$2 != null) {
          return fail(applied.$2!, lineNo);
        }
        state.optionSettings.add(
          OptionSetting(
            location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo),
            key: optionPair.$1,
            value: optionPair.$2,
          ),
        );
        state.options = applied.$1;
        continue;
      }
      if (code.startsWith('option')) {
        return fail(_foundExpected(code, _directiveFailurePosition(code)), lineNo);
      }
      final plugin = _parsePlugin(code, lineNo);
      if (plugin != null) {
        state.plugins.add(plugin);
        continue;
      }
      if (code.startsWith('plugin')) {
        return fail(_foundExpected(code, _directiveFailurePosition(code)), lineNo);
      }
      final pushMeta = _parsePushMeta(code);
      if (pushMeta != null) {
        state.metaStack.add(pushMeta);
        continue;
      }
      final popMeta = _parsePopMeta(code);
      if (popMeta != null) {
        final at = state.metaStack.lastIndexWhere((entry) => entry.key == popMeta);
        if (at < 0) {
          return fail('invalid popmeta', lineNo);
        }
        state.metaStack.removeAt(at);
        continue;
      }
      final push = _parsePushTag(code);
      if (push != null) {
        state.tagStack.add(push);
        continue;
      }
      final pop = _parsePopTag(code);
      if (pop != null) {
        final at = state.tagStack.lastIndexOf(pop);
        if (at < 0) {
          return fail('invalid poptag', lineNo);
        }
        state.tagStack.removeAt(at);
        continue;
      }
      final header = _parseDirectiveHeader(code, lineNo);
      if (header == null) {
        final dateError = _invalidDateMessage(code);
        final failurePos = _directiveFailurePosition(code);
        final dated = date().parse(code) is Success;
        return fail(dateError ?? (dated ? _foundExpected(code, failurePos) : _foundTopLevel(code, failurePos)), lineNo);
      }
      final applied = _withPushedTags(header, state.tagStack);
      if (applied.body is TransactionBody) {
        final postings = <ParsedPosting>[];
        final metaEntries = <MetaEntry>[];
        final seenMeta = <String>{};
        final txn = (applied.body as TransactionBody).value;
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
            index += 1;
            continue;
          }
          if (!(postingCode.startsWith(' ') || postingCode.startsWith('\t'))) {
            break;
          }
          final postingLine = index + firstLine;
          final trimmed = postingCode.trimLeft();
          final tagsLinks = _parseTagsLinksLine(trimmed);
          if (tagsLinks != null) {
            if (lastPosting != null) {
              final entries = [...lastPosting.meta.entries];
              for (final tag in tagsLinks.tags) {
                entries.add(MetaEntry(key: '', value: MetaValue.tag(tag)));
              }
              final updated = lastPosting.copyWith(meta: Meta(entries: entries));
              postings[postings.length - 1] = updated;
              lastPosting = updated;
              endLine = postingLine;
              index += 1;
              continue;
            }
            tags.addAll(tagsLinks.tags);
            links.addAll(tagsLinks.links);
            endLine = postingLine;
            index += 1;
            continue;
          }
          final meta = _parseMetaEntry(trimmed);
          if (meta != null) {
            if (lastPosting != null) {
              final postingMeta = lastPosting.meta;
              final keys = {for (final entry in postingMeta.entries) entry.key};
              if (!keys.add(meta.key)) {
                noteError('duplicate key ${meta.key}', postingLine);
              } else {
                final updated = lastPosting.copyWith(meta: Meta(entries: [...postingMeta.entries, meta]));
                postings[postings.length - 1] = updated;
                lastPosting = updated;
              }
            } else if (!seenMeta.add(meta.key)) {
              noteError('duplicate key ${meta.key}', postingLine);
            } else {
              metaEntries.add(meta);
            }
            endLine = postingLine;
            index += 1;
            continue;
          }
          final posting = _parsePosting(trimmed, postingLine);
          if (posting == null) {
            noteError(_foundPosting(trimmed, _postingFailurePosition(trimmed)), postingLine);
            index += 1;
            skipIndentedBlock();
            postings.clear();
            break;
          }
          postings.add(posting);
          lastPosting = posting;
          endLine = postingLine;
          index += 1;
        }
        if (postings.isEmpty && state.errors.isNotEmpty) {
          continue;
        }
        final txnDirective = applied.copyWith(
          location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: endLine),
          meta: _metaWithStack(state.metaStack, metaEntries),
          body: DirectiveBody.transaction(txn.copyWith(tags: tags, links: links, postings: postings)),
        );
        final accountError = _accountTypeError(txnDirective, state.options);
        if (accountError != null) {
          return fail(accountError, lineNo);
        }
        state.directives.add(txnDirective);
      } else {
        final metaEntries = <MetaEntry>[];
        final seenMeta = <String>{};
        var endLine = lineNo;
        while (index < lines.length) {
          final raw = lines[index];
          if (raw.trimLeft().startsWith(';')) {
            index += 1;
            continue;
          }
          final codeLine = _stripTrailingComment(raw).trimRight();
          if (codeLine.trim().isEmpty) {
            index += 1;
            continue;
          }
          if (!(codeLine.startsWith(' ') || codeLine.startsWith('\t'))) {
            break;
          }
          final metaLine = index + firstLine;
          final trimmed = codeLine.trimLeft();
          final meta = _parseMetaEntry(trimmed);
          if (meta == null) {
            return fail(_foundExpected(trimmed, 0), metaLine);
          }
          if (!seenMeta.add(meta.key)) {
            noteError('duplicate key ${meta.key}', metaLine);
          } else {
            metaEntries.add(meta);
          }
          endLine = metaLine;
          index += 1;
        }
        final directive = applied.copyWith(
          location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: endLine),
          meta: _metaWithStack(state.metaStack, metaEntries),
        );
        final accountError = _accountTypeError(directive, state.options);
        if (accountError != null) {
          return fail(accountError, lineNo);
        }
        state.directives.add(directive);
      }
    }
    if (!isRoot) {
      return ParsedLedger.directives(directives: const [], options: state.options, info: info());
    }
    if (state.errors.isNotEmpty) {
      return ParsedLedger.errors(errors: state.errors, options: state.options, info: info());
    }
    if (state.tagStack.isNotEmpty) {
      return fail('invalid pushtag', firstLine + lines.length - 1);
    }
    if (state.metaStack.isNotEmpty) {
      return fail('invalid pushmeta', firstLine + lines.length - 1);
    }
    state.directives.sort(compareParsedDirectives);
    return ParsedLedger.directives(directives: state.directives, options: state.options, info: info());
  }

  String? _parseInclude(String line) {
    final result = (string('include') & spaces() & quotedString()).end().parse(line);
    return result is Success ? result.value[2] as String : null;
  }

  String _includeContextKey(List<String> tags, List<MetaEntry> meta) {
    final tagPart = [...tags]..sort();
    final metaPart = [for (final entry in meta) '${entry.key}=${entry.value}']..sort();
    return '${tagPart.join('\u{1e}')}\u{1f}${metaPart.join('\u{1e}')}';
  }

  (String, String)? _parseOption(String line) {
    final result = (string('option') & spaces() & quotedString() & spaces() & quotedString()).end().parse(line);
    if (result is! Success) {
      return null;
    }
    return (result.value[2] as String, result.value[4] as String);
  }

  Plugin? _parsePlugin(String line, int lineNo) {
    final location = BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo);
    final withConfig = (string('plugin') & spaces() & quotedString() & spaces() & quotedString()).end().parse(line);
    if (withConfig is Success) {
      return Plugin(name: withConfig.value[2] as String, config: withConfig.value[4] as String, location: location);
    }
    final bare = (string('plugin') & spaces() & quotedString()).end().parse(line);
    if (bare is Success) {
      return Plugin(name: bare.value[2] as String, location: location);
    }
    return null;
  }

  String? _accountTypeError(ParsedDirective directive, LedgerOptions options) {
    final prefixes = [
      options.accountPrefixes.assets,
      options.accountPrefixes.liabilities,
      options.accountPrefixes.equity,
      options.accountPrefixes.income,
      options.accountPrefixes.expenses,
    ];
    for (final account in _accountsIn(directive)) {
      final root = account.name.split(':').first;
      if (!prefixes.contains(root)) {
        return 'unknown account type $root, must be one of ${prefixes.join(', ')}';
      }
    }
    return null;
  }

  Iterable<Account> _accountsIn(ParsedDirective directive) sync* {
    switch (directive.body) {
      case OpenBody(:final account):
        yield account;
      case CloseBody(:final account):
        yield account;
      case BalanceBody(:final account):
        yield account;
      case PadBody(:final account, :final sourceAccount):
        yield account;
        yield sourceAccount;
      case NoteBody(:final account):
        yield account;
      case DocumentBody(:final account):
        yield account;
      case TransactionBody(:final value):
        for (final posting in value.postings) {
          yield posting.account;
        }
      case PriceBody():
      case CommodityBody():
      case EventBody():
      case QueryBody():
      case CustomBody():
        break;
    }
  }

  String? _parsePushTag(String line) {
    final result = (string('pushtag') & spaces() & _tagOrLink()).end().parse(line);
    if (result is! Success) {
      return null;
    }
    final tag = result.value[2];
    return tag is Tag ? tag.name : null;
  }

  String? _parsePopTag(String line) {
    final result = (string('poptag') & spaces() & _tagOrLink()).end().parse(line);
    if (result is! Success) {
      return null;
    }
    final tag = result.value[2];
    return tag is Tag ? tag.name : null;
  }

  MetaEntry? _parsePushMeta(String line) {
    final result = (string('pushmeta') & spaces() & metaEntry()).end().parse(line);
    return result is Success ? result.value[2] as MetaEntry : null;
  }

  String? _parsePopMeta(String line) {
    final key = (pattern('a-z') & pattern(r'A-Za-z0-9_-').star()).flatten();
    final result = (string('popmeta') & spaces() & key & spaces() & char(':') & spaces()).end().parse(line);
    return result is Success ? result.value[2] as String : null;
  }

  Meta _metaWithStack(List<MetaEntry> stack, List<MetaEntry> explicit) {
    final byKey = <String, MetaEntry>{};
    final order = <String>[];
    for (final entry in stack) {
      if (!byKey.containsKey(entry.key)) {
        order.add(entry.key);
      }
      byKey[entry.key] = entry;
    }
    for (final entry in explicit) {
      if (!byKey.containsKey(entry.key)) {
        order.add(entry.key);
      }
      byKey[entry.key] = entry;
    }
    return Meta(entries: [for (final key in order) byKey[key]!]);
  }

  List<Tag> _uniqueTags(Iterable<Tag> tags) {
    final seen = <String>{};
    final out = <Tag>[];
    for (final tag in tags) {
      if (seen.add(tag.name)) {
        out.add(tag);
      }
    }
    return out;
  }

  ParsedDirective _withPushedTags(ParsedDirective directive, List<String> tagStack) {
    if (tagStack.isEmpty) {
      return directive;
    }
    final fromStack = <Tag>[];
    final seen = <String>{};
    for (final name in tagStack) {
      if (seen.add(name)) {
        fromStack.add(Tag(name: name));
      }
    }
    return switch (directive.body) {
      TransactionBody(:final value) => directive.copyWith(
        body: DirectiveBody.transaction(value.copyWith(tags: _uniqueTags([...fromStack, ...value.tags]))),
      ),
      DocumentBody(:final account, :final filename, :final tags, :final links) => directive.copyWith(
        body: DirectiveBody.document(
          account: account,
          filename: filename,
          tags: _uniqueTags([...fromStack, ...tags]),
          links: links,
        ),
      ),
      NoteBody(:final account, :final comment, :final tags, :final links) => directive.copyWith(
        body: DirectiveBody.note(
          account: account,
          comment: comment,
          tags: _uniqueTags([...fromStack, ...tags]),
          links: links,
        ),
      ),
      _ => directive,
    };
  }

  bool _isOrgModeTitle(String line) {
    // Beancount ignores '*' at column 0 when more text follows (`* Heading`, `** Nested`).
    return line.startsWith('*') && line.length > 1;
  }

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
    final parser = [
      open,
      close,
      commodity,
      balance,
      pad,
      note,
      price,
      event,
      query,
      document,
      custom,
      transaction,
    ].toChoiceParser(failureJoiner: selectFarthest).cast<ParsedDirective>().end();
    final result = parser.parse(line);
    if (result is Failure) {
      _lastFailurePosition = result.position;
      return null;
    }
    return result.value;
  }

  Parser<({Amount amount, BeanNumber? tolerance})> _balanceAmount() {
    final withTolerance = (numberExpr() & spaces() & char('~') & spaces() & numberExpr() & spaces() & currency()).map((
      values,
    ) {
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
    final number = numberExpr().map(CustomValue.number);
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

  MetaEntry? _parseMetaEntry(String line) {
    final result = metaEntry().end().parse(line);
    return result is Success ? result.value : null;
  }

  bool _hasUnclosedQuote(String input) {
    var open = false;
    for (var i = 0; i < input.length; i += 1) {
      final ch = input[i];
      if (ch == '\\' && open && i + 1 < input.length) {
        i += 1;
        continue;
      }
      if (ch == '"') {
        open = !open;
      }
    }
    return open;
  }

  String? _invalidDateMessage(String line) {
    final match = RegExp(r'^(\d{4})[-/](\d{2})[-/](\d{2})').firstMatch(line);
    if (match == null) {
      return null;
    }
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12) {
      return "found 'ERROR month out of range'";
    }
    if (day < 1 || day > 31) {
      return "found 'ERROR day out of range'";
    }
    return null;
  }

  ParsedPosting? _parsePosting(String line, int lineNo) {
    final location = BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo);
    final accountResult = account().parse(line);
    if (accountResult is! Success) {
      _lastFailurePosition = accountResult is Failure ? accountResult.position : 0;
      return null;
    }
    var position = accountResult.position;
    IncompleteAmount? units;
    ParsedCost? cost;
    ParsedPrice? price;

    final unitsAttempt = (spaces() & incompleteAmount()).parse(line.substring(position));
    if (unitsAttempt is Success) {
      units = unitsAttempt.value[1] as IncompleteAmount;
      position += unitsAttempt.position;
    }

    final costWs = spaces().parse(line.substring(position));
    final costPos = costWs is Success ? position + costWs.position : position;
    if (costPos < line.length && line[costPos] == '{') {
      final costResult = costSpec().parse(line.substring(costPos));
      if (costResult is! Success) {
        _lastFailurePosition = costPos + (costResult is Failure ? costResult.position : 0);
        return null;
      }
      cost = costResult.value;
      position = costPos + costResult.position;
    }

    final priceWs = spaces().parse(line.substring(position));
    final pricePos = priceWs is Success ? position + priceWs.position : position;
    if (pricePos < line.length && line[pricePos] == '@') {
      final priceResult = priceSpec().parse(line.substring(pricePos));
      if (priceResult is! Success) {
        _lastFailurePosition = pricePos + (priceResult is Failure ? priceResult.position : 0);
        return null;
      }
      price = priceResult.value;
      position = pricePos + priceResult.position;
    }

    final trail = spaces().parse(line.substring(position));
    if (trail is Success) {
      position += trail.position;
    }
    if (position != line.length) {
      _lastFailurePosition = position;
      return null;
    }
    return ParsedPosting(location: location, account: accountResult.value, units: units, cost: cost, price: price);
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

  String _foundPosting(String input, int position) {
    final found = _foundLexeme(input, position);
    return "found '$found'";
  }

  String _foundTopLevel(String input, int position) {
    final found = _foundLexeme(input, position);
    final ch = found.isEmpty ? '' : found[0];
    return 'found $ch expected transaction, directive, or end of input';
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
    if (!_isTokenStart(ch)) {
      return 'ERROR unrecognized token';
    }
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
      if (c == ' ' || c == '\t' || c == ':' || '{}[]()@~,*/"'.contains(c)) {
        break;
      }
      j += 1;
    }
    return input.substring(i, j);
  }

  bool _isTokenStart(String ch) {
    final code = ch.codeUnitAt(0);
    if ((code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a)) {
      return true;
    }
    return '{}[]()@~,*/#+^!&?%"\'.\\-_'.contains(ch);
  }
}

int compareParsedDirectives(ParsedDirective a, ParsedDirective b) {
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

class _ParseState {
  LedgerOptions options = const LedgerOptions();
  final List<Plugin> plugins = <Plugin>[];
  final List<OptionSetting> optionSettings = <OptionSetting>[];
  final List<ParsedDirective> directives = <ParsedDirective>[];
  final List<ParseError> errors = <ParseError>[];
  final List<String> tagStack = <String>[];
  final List<MetaEntry> metaStack = <MetaEntry>[];
  bool aborted = false;
}
