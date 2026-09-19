// Line-oriented Beancount document parser built on petitparser fragments.

import 'package:guar_parser/src/domain/domain.dart';
import 'package:guar_parser/src/parser/include.dart';
import 'package:guar_parser/src/parser/observation.dart';
import 'package:guar_parser/src/parser/option_apply.dart';
import 'package:guar_parser/src/parser/tokens.dart';
import 'package:petitparser/petitparser.dart';

class BeancountGrammar {
  BeancountGrammar({this.filename = '', this.firstLine = 1, IncludeController? includes, this.recover = false})
    : includes = includes ?? IncludeController(readFile: (_) => null);

  final String filename;
  final int firstLine;
  final IncludeController includes;
  final bool recover;

  ParsedLedger parse(String source, {LedgerOptions? initialOptions, bool isRoot = true, bool honorOptions = true}) {
    final _ParseState state = _ParseState();
    if (initialOptions != null) {
      state.options = initialOptions;
    }
    return _parseInto(source, state, isRoot: isRoot, honorOptions: honorOptions);
  }

  ParsedLedger _parseInto(String source, _ParseState state, {required bool isRoot, bool honorOptions = true}) {
    final String normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final List<String> lines = normalized.split('\n');
    ProcessingInfo info() {
      final ({List<Currency> commodities, DisplayContext displayContext}) observed = observeDirectives(
        state.directives,
      );
      return ProcessingInfo(
        filename: filename.isEmpty ? null : filename,
        include: List<String>.unmodifiable(includes.includeLog),
        commodities: observed.commodities,
        plugin: List<Plugin>.unmodifiable(state.plugins),
        displayContext: observed.displayContext,
        optionSettings: List<OptionSetting>.unmodifiable(state.optionSettings),
      );
    }

    List<ParseWarning> warnings() => List<ParseWarning>.unmodifiable(state.warnings);

    void noteWarning(String message, int lineNo) {
      state.warnings.add(
        ParseWarning(
          message: message,
          location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo),
        ),
      );
    }

    void noteError(String message, int lineNo) {
      state.errors.add(
        ParseError(
          message: message,
          location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo),
        ),
      );
    }

    int index = 0;
    void skipIndentedBlock() {
      while (index < lines.length) {
        final String blockRaw = lines[index];
        if (blockRaw.trimLeft().startsWith(';')) {
          index += 1;
          continue;
        }
        final String blockCode = _stripTrailingComment(blockRaw).trimRight();
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

    ParsedLedger? fail(String message, int lineNo) {
      final ParseError error = ParseError(
        message: message,
        location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo),
      );
      if (recover) {
        state.errors.add(error);
        skipIndentedBlock();
        return null;
      }
      state.aborted = true;
      state.errors
        ..clear()
        ..add(error);
      return ParsedLedger.errors(
        errors: <ParseError>[error],
        warnings: warnings(),
        options: state.options,
        info: info(),
      );
    }

    while (index < lines.length && !state.aborted) {
      final String raw = lines[index];
      final int lineNo = index + firstLine;
      index += 1;
      String code = _stripTrailingComment(raw).trimRight();
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
        final ParsedLedger? halted = fail(_foundExpected(code.trimLeft(), 0), lineNo);
        if (halted != null) {
          return halted;
        }
        continue;
      }
      while (_hasUnclosedQuote(code) && index < lines.length) {
        final StringBuffer buffer = StringBuffer(code)
          ..write('\n')
          ..write(lines[index]);
        code = buffer.toString();
        index += 1;
      }
      final String? includePattern = _parseInclude(code);
      if (includePattern != null) {
        final IncludeOutcome outcome = includes.open(
          pattern: includePattern,
          fromFilename: filename,
          contextKey: _includeContextKey(state.tagStack, state.metaStack),
        );
        switch (outcome) {
          case IncludeSkip():
            continue;
          case IncludeDuplicate():
            final ParsedLedger? halted = fail('duplicate include', lineNo);
            if (halted != null) {
              return halted;
            }
            continue;
          case IncludeFailed():
            final ParsedLedger? halted = fail('include failed', lineNo);
            if (halted != null) {
              return halted;
            }
            continue;
          case IncludeLoaded(:final List<IncludeHit> files):
            for (final IncludeHit hit in files) {
              BeancountGrammar(
                filename: hit.path,
                includes: includes,
                recover: recover,
              )._parseInto(hit.source, state, isRoot: false, honorOptions: false);
              if (state.aborted) {
                return ParsedLedger.errors(
                  errors: state.errors,
                  warnings: warnings(),
                  options: state.options,
                  info: info(),
                );
              }
            }
            continue;
        }
      }
      if (code.startsWith('include')) {
        final ParsedLedger? halted = fail(_foundExpected(code, _directiveFailurePosition(code)), lineNo);
        if (halted != null) {
          return halted;
        }
        continue;
      }
      final (String, String)? optionPair = _parseOption(code);
      if (optionPair != null) {
        final (LedgerOptions, String?) applied = applyLedgerOption(state.options, optionPair.$1, optionPair.$2);
        if (applied.$2 != null) {
          final ParsedLedger? halted = fail(applied.$2!, lineNo);
          if (halted != null) {
            return halted;
          }
          continue;
        }
        if (!honorOptions) {
          noteWarning('option ignored in included file', lineNo);
          continue;
        }
        state.optionSettings.add(
          OptionSetting(
            location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo),
            key: optionPair.$1,
            value: optionPair.$2,
          ),
        );
        state.options = applied.$1;
        final String? warning = ledgerOptionWarning(optionPair.$1);
        if (warning != null) {
          noteWarning(warning, lineNo);
        }
        continue;
      }
      if (code.startsWith('option')) {
        final ParsedLedger? halted = fail(_foundExpected(code, _directiveFailurePosition(code)), lineNo);
        if (halted != null) {
          return halted;
        }
        continue;
      }
      final Plugin? plugin = _parsePlugin(code, lineNo);
      if (plugin != null) {
        if (honorOptions) {
          state.plugins.add(plugin);
        } else {
          noteWarning('plugin ignored in included file', lineNo);
        }
        continue;
      }
      if (code.startsWith('plugin')) {
        final ParsedLedger? halted = fail(_foundExpected(code, _directiveFailurePosition(code)), lineNo);
        if (halted != null) {
          return halted;
        }
        continue;
      }
      final MetaEntry? pushMeta = _parsePushMeta(code);
      if (pushMeta != null) {
        state.metaStack.add(pushMeta);
        continue;
      }
      final String? popMeta = _parsePopMeta(code);
      if (popMeta != null) {
        final int at = state.metaStack.lastIndexWhere((MetaEntry entry) => entry.key == popMeta);
        if (at < 0) {
          final ParsedLedger? halted = fail('invalid popmeta', lineNo);
          if (halted != null) {
            return halted;
          }
          continue;
        }
        state.metaStack.removeAt(at);
        continue;
      }
      final String? push = _parsePushTag(code);
      if (push != null) {
        state.tagStack.add(push);
        continue;
      }
      final String? pop = _parsePopTag(code);
      if (pop != null) {
        final int at = state.tagStack.lastIndexOf(pop);
        if (at < 0) {
          final ParsedLedger? halted = fail('invalid poptag', lineNo);
          if (halted != null) {
            return halted;
          }
          continue;
        }
        state.tagStack.removeAt(at);
        continue;
      }
      final ParsedDirective? header = _parseDirectiveHeader(
        code,
        lineNo,
        allowPipe: state.options.allowPipeSeparator == true,
      );
      if (header == null) {
        final String? dateError = _invalidDateMessage(code);
        final bool allowPipe = state.options.allowPipeSeparator == true;
        final int failurePos = _directiveFailurePosition(code, allowPipe: allowPipe);
        final bool dated = date().parse(code) is Success;
        if (dateError != null) {
          final ParsedLedger? halted = fail(dateError, lineNo);
          if (halted != null) {
            return halted;
          }
          continue;
        }
        if (dated && !allowPipe && _txnStringsContainPipe(code)) {
          final ParsedLedger? halted = fail('Pipe symbol is deprecated.', lineNo);
          if (halted != null) {
            return halted;
          }
          continue;
        }
        final ParsedLedger? halted = fail(
          dated ? _foundExpected(code, failurePos) : _foundTopLevel(code, failurePos),
          lineNo,
        );
        if (halted != null) {
          return halted;
        }
        continue;
      }
      final ParsedDirective applied = _withPushedTags(header, state.tagStack);
      if (applied.body is TransactionBody) {
        final List<ParsedPosting> postings = <ParsedPosting>[];
        final List<MetaEntry> metaEntries = <MetaEntry>[];
        final Set<String> seenMeta = <String>{};
        final ParsedTransaction txn = (applied.body as TransactionBody).value;
        final List<Tag> tags = <Tag>[...txn.tags];
        final List<Link> links = <Link>[...txn.links];
        ParsedPosting? lastPosting;
        int endLine = lineNo;
        while (index < lines.length) {
          final String postingRaw = lines[index];
          if (postingRaw.trimLeft().startsWith(';')) {
            index += 1;
            continue;
          }
          final String postingCode = _stripTrailingComment(postingRaw).trimRight();
          if (postingCode.trim().isEmpty) {
            index += 1;
            continue;
          }
          if (!(postingCode.startsWith(' ') || postingCode.startsWith('\t'))) {
            break;
          }
          final int postingLine = index + firstLine;
          final String trimmed = postingCode.trimLeft();
          final ({List<Link> links, List<Tag> tags})? tagsLinks = _parseTagsLinksLine(trimmed);
          if (tagsLinks != null) {
            if (lastPosting != null) {
              final List<MetaEntry> entries = <MetaEntry>[...lastPosting.meta.entries];
              for (final Tag tag in tagsLinks.tags) {
                entries.add(MetaEntry(key: '', value: MetaValue.tag(tag)));
              }
              final ParsedPosting updated = lastPosting.copyWith(meta: Meta(entries: entries));
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
          final MetaEntry? meta = _parseMetaEntry(trimmed);
          if (meta != null) {
            if (lastPosting != null) {
              final Meta postingMeta = lastPosting.meta;
              final Set<String> keys = <String>{for (final MetaEntry entry in postingMeta.entries) entry.key};
              if (!keys.add(meta.key)) {
                noteError('duplicate key ${meta.key}', postingLine);
              } else {
                final ParsedPosting updated = lastPosting.copyWith(
                  meta: Meta(entries: <MetaEntry>[...postingMeta.entries, meta]),
                );
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
          final ParsedPosting? posting = _parsePosting(trimmed, postingLine);
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
        final ParsedDirective txnDirective = applied.copyWith(
          location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: endLine),
          meta: _metaWithStack(state.metaStack, metaEntries),
          body: DirectiveBody.transaction(txn.copyWith(tags: tags, links: links, postings: postings)),
        );
        final String? accountError = _accountTypeError(txnDirective, state.options);
        if (accountError != null) {
          final ParsedLedger? halted = fail(accountError, lineNo);
          if (halted != null) {
            return halted;
          }
          continue;
        }
        state.directives.add(txnDirective);
      } else {
        final List<MetaEntry> metaEntries = <MetaEntry>[];
        final Set<String> seenMeta = <String>{};
        int endLine = lineNo;
        while (index < lines.length) {
          final String raw = lines[index];
          if (raw.trimLeft().startsWith(';')) {
            index += 1;
            continue;
          }
          final String codeLine = _stripTrailingComment(raw).trimRight();
          if (codeLine.trim().isEmpty) {
            index += 1;
            continue;
          }
          if (!(codeLine.startsWith(' ') || codeLine.startsWith('\t'))) {
            break;
          }
          final int metaLine = index + firstLine;
          final String trimmed = codeLine.trimLeft();
          final MetaEntry? meta = _parseMetaEntry(trimmed);
          if (meta == null) {
            final ParsedLedger? halted = fail(_foundExpected(trimmed, 0), metaLine);
            if (halted != null) {
              return halted;
            }
            continue;
          }
          if (!seenMeta.add(meta.key)) {
            noteError('duplicate key ${meta.key}', metaLine);
          } else {
            metaEntries.add(meta);
          }
          endLine = metaLine;
          index += 1;
        }
        final ParsedDirective directive = applied.copyWith(
          location: BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: endLine),
          meta: _metaWithStack(state.metaStack, metaEntries),
        );
        final String? accountError = _accountTypeError(directive, state.options);
        if (accountError != null) {
          final ParsedLedger? halted = fail(accountError, lineNo);
          if (halted != null) {
            return halted;
          }
          continue;
        }
        state.directives.add(directive);
      }
    }
    if (!isRoot) {
      return ParsedLedger.directives(
        directives: const <ParsedDirective>[],
        warnings: warnings(),
        options: state.options,
        info: info(),
      );
    }
    if (state.errors.isNotEmpty && !recover) {
      return ParsedLedger.errors(errors: state.errors, warnings: warnings(), options: state.options, info: info());
    }
    if (state.tagStack.isNotEmpty) {
      final ParsedLedger? halted = fail('invalid pushtag', firstLine + lines.length - 1);
      if (halted != null) {
        return halted;
      }
    }
    if (state.metaStack.isNotEmpty) {
      final ParsedLedger? halted = fail('invalid pushmeta', firstLine + lines.length - 1);
      if (halted != null) {
        return halted;
      }
    }
    state.directives.sort(compareParsedDirectives);
    return ParsedLedger.directives(
      directives: state.directives,
      errors: List<ParseError>.unmodifiable(state.errors),
      warnings: warnings(),
      options: state.options,
      info: info(),
    );
  }

  String? _parseInclude(String line) {
    final Result<List<dynamic>> result = (string('include') & spaces() & quotedString()).end().parse(line);
    return result is Success ? result.value[2] as String : null;
  }

  String _includeContextKey(List<String> tags, List<MetaEntry> meta) {
    final List<String> tagPart = <String>[...tags]..sort();
    final List<String> metaPart = <String>[for (final MetaEntry entry in meta) '${entry.key}=${entry.value}']..sort();
    return '${tagPart.join('\u{1e}')}\u{1f}${metaPart.join('\u{1e}')}';
  }

  (String, String)? _parseOption(String line) {
    final Result<List<dynamic>> result = (string('option') & spaces() & quotedString() & spaces() & quotedString())
        .end()
        .parse(line);
    if (result is! Success) {
      return null;
    }
    return (result.value[2] as String, result.value[4] as String);
  }

  Plugin? _parsePlugin(String line, int lineNo) {
    final BeanLocation location = BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo);
    final Result<List<dynamic>> withConfig = (string('plugin') & spaces() & quotedString() & spaces() & quotedString())
        .end()
        .parse(line);
    if (withConfig is Success) {
      return Plugin(name: withConfig.value[2] as String, config: withConfig.value[4] as String, location: location);
    }
    final Result<List<dynamic>> bare = (string('plugin') & spaces() & quotedString()).end().parse(line);
    if (bare is Success) {
      return Plugin(name: bare.value[2] as String, location: location);
    }
    return null;
  }

  String? _accountTypeError(ParsedDirective directive, LedgerOptions options) {
    final List<String> prefixes = <String>[
      options.accountPrefixes.assets ?? 'Assets',
      options.accountPrefixes.liabilities ?? 'Liabilities',
      options.accountPrefixes.equity ?? 'Equity',
      options.accountPrefixes.income ?? 'Income',
      options.accountPrefixes.expenses ?? 'Expenses',
    ];
    for (final Account account in _accountsIn(directive)) {
      final String root = account.name.split(':').first;
      if (!prefixes.contains(root)) {
        return 'unknown account type $root, must be one of ${prefixes.join(', ')}';
      }
    }
    return null;
  }

  Iterable<Account> _accountsIn(ParsedDirective directive) sync* {
    switch (directive.body) {
      case OpenBody(:final Account account):
        yield account;
      case CloseBody(:final Account account):
        yield account;
      case BalanceBody(:final Account account):
        yield account;
      case PadBody(:final Account account, :final Account sourceAccount):
        yield account;
        yield sourceAccount;
      case NoteBody(:final Account account):
        yield account;
      case DocumentBody(:final Account account):
        yield account;
      case TransactionBody(:final ParsedTransaction value):
        for (final ParsedPosting posting in value.postings) {
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
    final Result<List<dynamic>> result = (string('pushtag') & spaces() & _tagOrLink()).end().parse(line);
    if (result is! Success) {
      return null;
    }
    final dynamic tag = result.value[2];
    return tag is Tag ? tag.name : null;
  }

  String? _parsePopTag(String line) {
    final Result<List<dynamic>> result = (string('poptag') & spaces() & _tagOrLink()).end().parse(line);
    if (result is! Success) {
      return null;
    }
    final dynamic tag = result.value[2];
    return tag is Tag ? tag.name : null;
  }

  MetaEntry? _parsePushMeta(String line) {
    final Result<List<dynamic>> result = (string('pushmeta') & spaces() & metaEntry()).end().parse(line);
    return result is Success ? result.value[2] as MetaEntry : null;
  }

  String? _parsePopMeta(String line) {
    final Parser<String> key = (pattern('a-z') & pattern('A-Za-z0-9_-').star()).flatten();
    final Result<List<dynamic>> result = (string('popmeta') & spaces() & key & spaces() & char(':') & spaces())
        .end()
        .parse(line);
    return result is Success ? result.value[2] as String : null;
  }

  Meta _metaWithStack(List<MetaEntry> stack, List<MetaEntry> explicit) {
    final Map<String, MetaEntry> byKey = <String, MetaEntry>{};
    final List<String> order = <String>[];
    for (final MetaEntry entry in stack) {
      if (!byKey.containsKey(entry.key)) {
        order.add(entry.key);
      }
      byKey[entry.key] = entry;
    }
    for (final MetaEntry entry in explicit) {
      if (!byKey.containsKey(entry.key)) {
        order.add(entry.key);
      }
      byKey[entry.key] = entry;
    }
    return Meta(entries: <MetaEntry>[for (final String key in order) byKey[key]!]);
  }

  List<Tag> _uniqueTags(Iterable<Tag> tags) {
    final Set<String> seen = <String>{};
    final List<Tag> out = <Tag>[];
    for (final Tag tag in tags) {
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
    final List<Tag> fromStack = <Tag>[];
    final Set<String> seen = <String>{};
    for (final String name in tagStack) {
      if (seen.add(name)) {
        fromStack.add(Tag(name: name));
      }
    }
    return switch (directive.body) {
      TransactionBody(:final ParsedTransaction value) => directive.copyWith(
        body: DirectiveBody.transaction(value.copyWith(tags: _uniqueTags(<Tag>[...fromStack, ...value.tags]))),
      ),
      DocumentBody(:final Account account, :final String filename, :final List<Tag> tags, :final List<Link> links) =>
        directive.copyWith(
          body: DirectiveBody.document(
            account: account,
            filename: filename,
            tags: _uniqueTags(<Tag>[...fromStack, ...tags]),
            links: links,
          ),
        ),
      NoteBody(:final Account account, :final String comment, :final List<Tag> tags, :final List<Link> links) =>
        directive.copyWith(
          body: DirectiveBody.note(
            account: account,
            comment: comment,
            tags: _uniqueTags(<Tag>[...fromStack, ...tags]),
            links: links,
          ),
        ),
      _ => directive,
    };
  }

  // Beancount ignores '*' at column 0 when more text follows (`* Heading`, `** Nested`).
  bool _isOrgModeTitle(String line) => line.startsWith('*') && line.length > 1;

  String _stripTrailingComment(String line) {
    const bool inString = false;
    // Strings are rare on comment-bearing lines; strip ; outside quotes.
    bool quoted = inString;
    for (int i = 0; i < line.length; i++) {
      final String ch = line[i];
      if (ch == '"') {
        quoted = !quoted;
      } else if (ch == ';' && !quoted) {
        return line.substring(0, i);
      }
    }
    return line;
  }

  ParsedDirective? _parseDirectiveHeader(String line, int lineNo, {bool allowPipe = false}) {
    final BeanLocation location = BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo);
    final Parser<ParsedDirective> open = (date() & spaces() & string('open') & spaces() & account() & _openTail()).map((
      List<dynamic> values,
    ) {
      final ({BookingMethod? booking, List<Currency> currencies}) tail =
          values[5] as ({List<Currency> currencies, BookingMethod? booking});
      return ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.open(account: values[4] as Account, currencies: tail.currencies, booking: tail.booking),
      );
    });
    final Parser<ParsedDirective> close = (date() & spaces() & string('close') & spaces() & account()).map(
      (List<dynamic> values) => ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.close(account: values[4] as Account),
      ),
    );
    final Parser<ParsedDirective> commodity = (date() & spaces() & string('commodity') & spaces() & currency()).map(
      (List<dynamic> values) => ParsedDirective(
        location: location,
        date: values[0] as BeanDate,
        body: DirectiveBody.commodity(currency: values[4] as Currency),
      ),
    );
    final Parser<ParsedDirective> transaction = (date() & spaces() & flag() & _txnTail(allowPipe: allowPipe)).map((
      List<dynamic> values,
    ) {
      final ({List<Link> links, String narration, String? payee, List<Tag> tags}) tail =
          values[3] as ({String? payee, String narration, List<Tag> tags, List<Link> links});
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
    final Parser<ParsedDirective> balance =
        (date() & spaces() & string('balance') & spaces() & account() & spaces() & _balanceAmount()).map((
          List<dynamic> values,
        ) {
          final ({Amount amount, BeanNumber? tolerance}) amountTol =
              values[6] as ({Amount amount, BeanNumber? tolerance});
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
    final Parser<ParsedDirective> pad =
        (date() & spaces() & string('pad') & spaces() & account() & spaces() & account()).map(
          (List<dynamic> values) => ParsedDirective(
            location: location,
            date: values[0] as BeanDate,
            body: DirectiveBody.pad(account: values[4] as Account, sourceAccount: values[6] as Account),
          ),
        );
    final Parser<ParsedDirective> note =
        (date() & spaces() & string('note') & spaces() & account() & spaces() & quotedString() & _tagsLinks()).map((
          List<dynamic> values,
        ) {
          final ({List<Link> links, List<Tag> tags}) tl = values[7] as ({List<Tag> tags, List<Link> links});
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
    final Parser<ParsedDirective> price =
        (date() & spaces() & string('price') & spaces() & currency() & spaces() & amount()).map(
          (List<dynamic> values) => ParsedDirective(
            location: location,
            date: values[0] as BeanDate,
            body: DirectiveBody.price(currency: values[4] as Currency, amount: values[6] as Amount),
          ),
        );
    final Parser<ParsedDirective> event =
        (date() & spaces() & string('event') & spaces() & quotedString() & spaces() & quotedString()).map(
          (
            List<dynamic> values,
          ) => ParsedDirective(
            location: location,
            date: values[0] as BeanDate,
            body: DirectiveBody.event(name: values[4] as String, description: values[6] as String),
          ),
        );
    final Parser<ParsedDirective> query =
        (date() & spaces() & string('query') & spaces() & quotedString() & spaces() & quotedString()).map(
          (
            List<dynamic> values,
          ) => ParsedDirective(
            location: location,
            date: values[0] as BeanDate,
            body: DirectiveBody.query(name: values[4] as String, queryString: values[6] as String),
          ),
        );
    final Parser<ParsedDirective> document =
        (date() & spaces() & string('document') & spaces() & account() & spaces() & quotedString() & _tagsLinks()).map((
          List<dynamic> values,
        ) {
          final ({List<Link> links, List<Tag> tags}) tl = values[7] as ({List<Tag> tags, List<Link> links});
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
    final Parser<ParsedDirective> custom =
        (date() & spaces() & string('custom') & spaces() & quotedString() & _customValues()).map(
          (List<dynamic> values) => ParsedDirective(
            location: location,
            date: values[0] as BeanDate,
            body: DirectiveBody.custom(type: values[4] as String, values: values[5] as List<CustomValue>),
          ),
        );
    final Parser<ParsedDirective> parser = <Parser<ParsedDirective>>[
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
    final Result<ParsedDirective> result = parser.parse(line);
    if (result is Failure) {
      _lastFailurePosition = result.position;
      return null;
    }
    return result.value;
  }

  Parser<({Amount amount, BeanNumber? tolerance})> _balanceAmount() {
    final Parser<({Amount amount, BeanNumber tolerance})> withTolerance =
        (numberExpr() & spaces() & char('~') & spaces() & numberExpr() & spaces() & currency()).map(
          (
            List<dynamic> values,
          ) => (
            amount: Amount(number: values[0] as BeanNumber, currency: values[6] as Currency),
            tolerance: values[4] as BeanNumber,
          ),
        );
    final Parser<({Amount amount, Null tolerance})> plain = amount().map(
      (Amount value) => (amount: value, tolerance: null),
    );
    return (withTolerance | plain).cast();
  }

  Parser<({List<Tag> tags, List<Link> links})> _tagsLinks() =>
      (spaces() & _tagOrLink()).star().map((List<List<dynamic>> values) {
        final List<Tag> tags = <Tag>[];
        final List<Link> links = <Link>[];
        for (final List<dynamic> part in values) {
          final dynamic item = part[1];
          if (item is Tag) {
            tags.add(item);
          } else if (item is Link) {
            links.add(item);
          }
        }
        return (tags: tags, links: links);
      });

  Parser<List<CustomValue>> _customValues() => (spaces() & _customValue()).star().map(
    (List<List<dynamic>> values) => <CustomValue>[for (final List<dynamic> part in values) part[1] as CustomValue],
  );

  Parser<CustomValue> _customValue() {
    final Parser<CustomValue> boolean = (string('TRUE').map((_) => true) | string('FALSE').map((_) => false))
        .cast<bool>()
        .map(
          CustomValue.boolean,
        );
    final Parser<CustomValue> dateValue = date().map(CustomValue.date);
    final Parser<CustomValue> text = quotedString().map(CustomValue.text);
    final Parser<CustomValue> amountValue = amount().map(CustomValue.amount);
    final Parser<CustomValue> number = numberExpr().map(CustomValue.number);
    final Parser<CustomValue> accountValue = account().map(CustomValue.account);
    final Parser<CustomValue> currencyValue = currency().map(CustomValue.currency);
    return (boolean | dateValue | text | amountValue | number | accountValue | currencyValue).cast<CustomValue>();
  }

  Parser<({List<Currency> currencies, BookingMethod? booking})> _openTail() {
    final Parser<List<Currency>> currencies =
        (spaces() & currency() & (char(',') & spaces().optional() & currency()).star()).map((List<dynamic> values) {
          final List<Currency> list = <Currency>[values[1] as Currency];
          for (final dynamic part in values[2] as List<dynamic>) {
            list.add((part as List<dynamic>)[2] as Currency);
          }
          return list;
        });
    final Parser<BookingMethod?> booking = (spaces() & quotedString()).map(
      (List<dynamic> values) => _bookingMethod(values[1] as String),
    );
    return (currencies.optional().map((List<Currency>? value) => value ?? <Currency>[]) & booking.optional()).map(
      (List<dynamic> values) => (currencies: values[0] as List<Currency>, booking: values[1] as BookingMethod?),
    );
  }

  BookingMethod? _bookingMethod(String value) => switch (value) {
    'STRICT' => BookingMethod.strict,
    'STRICT_WITH_SIZE' => BookingMethod.strictWithSize,
    'NONE' => BookingMethod.none,
    'AVERAGE' => BookingMethod.average,
    'FIFO' => BookingMethod.fifo,
    'LIFO' => BookingMethod.lifo,
    'HIFO' => BookingMethod.hifo,
    _ => null,
  };

  Parser<({String? payee, String narration, List<Tag> tags, List<Link> links})> _txnTail({required bool allowPipe}) {
    final Parser<({List<Link> links, List<Tag> tags})> tagsLinks = (spaces() & _tagOrLink()).star().map((
      List<List<dynamic>> values,
    ) {
      final List<Tag> tags = <Tag>[];
      final List<Link> links = <Link>[];
      for (final List<dynamic> part in values) {
        final dynamic item = part[1];
        if (item is Tag) {
          tags.add(item);
        } else if (item is Link) {
          links.add(item);
        }
      }
      return (tags: tags, links: links);
    });
    final Parser<void> skippedPipes = allowPipe ? (spaces() & char('|')).star().map((_) {}) : epsilon();
    final Parser<({List<Link> links, String narration, String payee, List<Tag> tags})> two =
        (skippedPipes & spaces() & quotedString() & skippedPipes & spaces() & quotedString() & skippedPipes & tagsLinks)
            .map((List<dynamic> values) {
              final ({List<Link> links, List<Tag> tags}) tl = values[7] as ({List<Tag> tags, List<Link> links});
              return (payee: values[2] as String, narration: values[5] as String, tags: tl.tags, links: tl.links);
            });
    final Parser<({List<Link> links, String narration, Null payee, List<Tag> tags})> one =
        (skippedPipes & spaces() & quotedString() & skippedPipes & tagsLinks).map((List<dynamic> values) {
          final ({List<Link> links, List<Tag> tags}) tl = values[4] as ({List<Tag> tags, List<Link> links});
          return (payee: null, narration: values[2] as String, tags: tl.tags, links: tl.links);
        });
    final Parser<({List<Link> links, String narration, Null payee, List<Tag> tags})> none = (skippedPipes & tagsLinks)
        .map((List<dynamic> values) {
          final ({List<Link> links, List<Tag> tags}) tl = values[1] as ({List<Tag> tags, List<Link> links});
          return (payee: null, narration: '', tags: tl.tags, links: tl.links);
        });
    return (two | one | none).cast();
  }

  Parser<Object> _tagOrLink() {
    final Parser<String> name = pattern('A-Za-z0-9_./-').plus().flatten();
    final Parser<Tag> tag = (char('#') & name).map((List<dynamic> values) => Tag(name: values[1] as String));
    final Parser<Link> link = (char('^') & name).map((List<dynamic> values) => Link(name: values[1] as String));
    return (tag | link).cast<Object>();
  }

  ({List<Tag> tags, List<Link> links})? _parseTagsLinksLine(String line) {
    final Parser<({List<Link> links, List<Tag> tags})> parser = (_tagOrLink() & (spaces() & _tagOrLink()).star())
        .end()
        .map((List<dynamic> values) {
          final List<Tag> tags = <Tag>[];
          final List<Link> links = <Link>[];
          void take(Object item) {
            if (item is Tag) {
              tags.add(item);
            } else if (item is Link) {
              links.add(item);
            }
          }

          take(values[0] as Object);
          for (final dynamic part in values[1] as List<dynamic>) {
            take((part as List<dynamic>)[1] as Object);
          }
          return (tags: tags, links: links);
        });
    final Result<({List<Link> links, List<Tag> tags})> result = parser.parse(line);
    return result is Success ? result.value : null;
  }

  MetaEntry? _parseMetaEntry(String line) {
    final Result<MetaEntry> result = metaEntry().end().parse(line);
    return result is Success ? result.value : null;
  }

  bool _hasUnclosedQuote(String input) {
    bool open = false;
    for (int i = 0; i < input.length; i += 1) {
      final String ch = input[i];
      if (ch == r'\' && open && i + 1 < input.length) {
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
    final RegExpMatch? match = RegExp(r'^(\d{4})[-/](\d{2})[-/](\d{2})').firstMatch(line);
    if (match == null) {
      return null;
    }
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    if (month < 1 || month > 12) {
      return "found 'ERROR month out of range'";
    }
    if (day < 1 || day > 31) {
      return "found 'ERROR day out of range'";
    }
    return null;
  }

  ParsedPosting? _parsePosting(String line, int lineNo) {
    final BeanLocation location = BeanLocation(filename: filename, linenoBegin: lineNo, linenoEnd: lineNo);
    Flag? postingFlag;
    final Account accountValue;
    int position = 0;
    final Result<List<dynamic>> flagged = (flag() & whitespaceInline().plus() & account()).parse(line);
    if (flagged is Success) {
      postingFlag = flagged.value[0] as Flag;
      accountValue = flagged.value[2] as Account;
      position = flagged.position;
    } else {
      final Result<Account> accountResult = account().parse(line);
      if (accountResult is! Success) {
        _lastFailurePosition = accountResult is Failure ? accountResult.position : 0;
        return null;
      }
      accountValue = accountResult.value;
      position = accountResult.position;
    }
    IncompleteAmount? units;
    ParsedCost? cost;
    ParsedPrice? price;

    final Result<List<dynamic>> unitsAttempt = (spaces() & incompleteAmount()).parse(line.substring(position));
    if (unitsAttempt is Success) {
      units = unitsAttempt.value[1] as IncompleteAmount;
      position += unitsAttempt.position;
    }

    final Result<void> costWs = spaces().parse(line.substring(position));
    final int costPos = costWs is Success ? position + costWs.position : position;
    if (costPos < line.length && line[costPos] == '{') {
      final Result<ParsedCost> costResult = costSpec().parse(line.substring(costPos));
      if (costResult is! Success) {
        _lastFailurePosition = costPos + (costResult is Failure ? costResult.position : 0);
        return null;
      }
      cost = costResult.value;
      position = costPos + costResult.position;
    }

    final Result<void> priceWs = spaces().parse(line.substring(position));
    final int pricePos = priceWs is Success ? position + priceWs.position : position;
    if (pricePos < line.length && line[pricePos] == '@') {
      final Result<ParsedPrice> priceResult = priceSpec().parse(line.substring(pricePos));
      if (priceResult is! Success) {
        _lastFailurePosition = pricePos + (priceResult is Failure ? priceResult.position : 0);
        return null;
      }
      price = priceResult.value;
      position = pricePos + priceResult.position;
    }

    final Result<void> trail = spaces().parse(line.substring(position));
    if (trail is Success) {
      position += trail.position;
    }
    if (position != line.length) {
      _lastFailurePosition = position;
      return null;
    }
    return ParsedPosting(
      location: location,
      flag: postingFlag,
      account: accountValue,
      units: units,
      cost: cost,
      price: price,
    );
  }

  int _lastFailurePosition = 0;

  int _directiveFailurePosition(String line, {bool allowPipe = false}) {
    _parseDirectiveHeader(line, 1, allowPipe: allowPipe);
    return _lastFailurePosition;
  }

  bool _txnStringsContainPipe(String line) {
    final Result<List<dynamic>> prefix = (date() & spaces() & flag()).parse(line);
    if (prefix is! Success) {
      return false;
    }
    final String rest = line.substring(prefix.position);
    bool inString = false;
    for (int i = 0; i < rest.length; i++) {
      final String ch = rest[i];
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (!inString && ch == '|') {
        return true;
      }
    }
    return false;
  }

  int _postingFailurePosition(String line) {
    _parsePosting(line, 1);
    return _lastFailurePosition;
  }

  String _foundExpected(String input, int position, {String expected = 'something else'}) {
    final String found = _foundLexeme(input, position);
    return "found '$found' expected $expected";
  }

  String _foundPosting(String input, int position) {
    final String found = _foundLexeme(input, position);
    return "found '$found'";
  }

  String _foundTopLevel(String input, int position) {
    final String found = _foundLexeme(input, position);
    final String ch = found.isEmpty ? '' : found[0];
    return 'found $ch expected transaction, directive, or end of input';
  }

  String _foundLexeme(String input, int position) {
    int i = position;
    while (i < input.length && (input.codeUnitAt(i) == 0x20 || input.codeUnitAt(i) == 0x09)) {
      i += 1;
    }
    if (i >= input.length) {
      return '';
    }
    final String ch = input[i];
    if (!_isTokenStart(ch)) {
      return 'ERROR unrecognized token';
    }
    if (ch == '"') {
      int j = i + 1;
      while (j < input.length && input[j] != '"') {
        if (input[j] == r'\' && j + 1 < input.length) {
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
    if ('{}[]()@~,*/|'.contains(ch)) {
      return ch;
    }
    int j = i + 1;
    while (j < input.length) {
      final String c = input[j];
      if (c == ' ' || c == '\t' || c == ':' || '{}[]()@~,*/|"'.contains(c)) {
        break;
      }
      j += 1;
    }
    return input.substring(i, j);
  }

  bool _isTokenStart(String ch) {
    final int code = ch.codeUnitAt(0);
    if ((code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a)) {
      return true;
    }
    return '{}[]()@~,*/|#+^!&?%"\'.\\-_'.contains(ch);
  }
}

int compareParsedDirectives(ParsedDirective a, ParsedDirective b) {
  final int byDate = compareBeanDate(a.date, b.date);
  if (byDate != 0) {
    return byDate;
  }
  final int byType = _typeOrder(a.body).compareTo(_typeOrder(b.body));
  if (byType != 0) {
    return byType;
  }
  return a.location.linenoBegin.compareTo(b.location.linenoBegin);
}

int _typeOrder(DirectiveBody body) => switch (body) {
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

class _ParseState {
  LedgerOptions options = const LedgerOptions();
  final List<Plugin> plugins = <Plugin>[];
  final List<OptionSetting> optionSettings = <OptionSetting>[];
  final List<ParsedDirective> directives = <ParsedDirective>[];
  final List<ParseError> errors = <ParseError>[];
  final List<ParseWarning> warnings = <ParseWarning>[];
  final List<String> tagStack = <String>[];
  final List<MetaEntry> metaStack = <MetaEntry>[];
  bool aborted = false;
}
