// Root option lines round-trip through booked defaults.

import 'package:decimal/decimal.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';
import 'package:test/test.dart';

void main() {
  test('empty source reads as defaults', () {
    final LoadedLedgerOptions loaded = readLedgerOptions('');
    expect(loaded.errors, isEmpty);
    expect(loaded.options.title, 'Beancount');
    expect(loaded.options.bookingMethod, BookingMethod.strict);
    expect(loaded.options.toleranceMultiplier.toString(), '0.5');
    expect(loaded.options.conversionCurrency, Currency(name: 'NOTHING'));
    expect(loaded.options.accountPreviousBalances.name, 'Equity:Opening-Balances');
    expect(loaded.guar.advancedUi, isFalse);
    expect(loaded.guar.writeDefaultOptions, isFalse);
    expect(loaded.guar.hidden, isEmpty);
  });

  test('keeps options that follow a broken line', () {
    final LoadedLedgerOptions loaded = readLedgerOptions('this is nonsense\noption "title" "Mine"\n');
    expect(loaded.options.title, 'Mine');
    expect(loaded.errors, isNotEmpty);
  });

  test('explicit options round-trip and omit derived accounts', () {
    final LedgerOptions options = LedgerOptions(
      title: 'Mine',
      documents: <String>['/docs'],
      operatingCurrency: <Currency>[
        Currency(name: 'USD'),
        Currency(name: 'EUR'),
      ],
      renderCommas: true,
      pluginProcessingMode: PluginProcessingMode.raw,
      accountPrefixes: const AccountPrefixes(equity: 'Capitaux'),
      accountRounding: Account(name: 'Capitaux:Rounding', type: AccountType.equity),
      bookingMethod: BookingMethod.fifo,
      toleranceMultiplier: OptionNumber(verbatim: '1.25', value: Decimal.parse('1.25')),
      inferredToleranceDefault: <InferredTolerance>[
        InferredTolerance(key: const CurrencyKey.all(), value: Decimal.parse('0.01')),
      ],
      displayPrecision: <DisplayPrecision>[
        DisplayPrecision(key: const DisplayPrecisionKey.all(), value: Decimal.parse('2')),
        DisplayPrecision(
          key: DisplayPrecisionKey.currency(Currency(name: 'USD')),
          value: Decimal.parse('2'),
        ),
        DisplayPrecision(
          key: DisplayPrecisionKey.pair(
            first: Currency(name: 'USD'),
            second: Currency(name: 'EUR'),
          ),
          value: Decimal.one,
        ),
      ],
    );
    const String body = '2020-01-01 open Assets:Cash\n';
    final String written = writeLedgerOptions(body, options);
    expect(written.contains('option "name_equity" "Capitaux"'), isTrue);
    expect(written.contains('account_previous_balances'), isFalse);
    expect(written.contains('account_unrealized_gains'), isFalse);
    expect(written.endsWith(body), isTrue);
    final LoadedLedgerOptions loaded = readLedgerOptions(written);
    expect(loaded.options.title, 'Mine');
    expect(loaded.options.bookingMethod, BookingMethod.fifo);
    expect(loaded.options.renderCommas, isTrue);
    expect(loaded.options.pluginProcessingMode, PluginProcessingMode.raw);
    expect(loaded.options.operatingCurrency.map((Currency currency) => currency.name), <String>['USD', 'EUR']);
    expect(loaded.options.documents, <String>['/docs']);
    expect(loaded.options.toleranceMultiplier.toString(), '1.25');
    expect(loaded.options.accountPrefixes.equity, 'Capitaux');
    expect(loaded.options.accountPreviousBalances.name, 'Capitaux:Opening-Balances');
    expect(loaded.options.accountRounding?.name, 'Capitaux:Rounding');
    expect(loaded.options.displayPrecision, hasLength(3));
    expect(loaded.options.inferredToleranceDefault.single.value, Decimal.parse('0.01'));
  });

  test('keeps a preserved option line verbatim', () {
    const String source =
        'option "insert_pythonpath" "TRUE" ; keep\n'
        'option "title" "Old"\n'
        '2020-01-01 open Assets:Cash\n';
    final String written = writeLedgerOptions(
      source,
      LedgerOptions(title: 'New', insertPythonpath: true),
      preserveKeys: const <String>{'insert_pythonpath'},
    );
    expect(
      written,
      'option "insert_pythonpath" "TRUE" ; keep\n'
      'option "title" "New"\n'
      '2020-01-01 open Assets:Cash\n',
    );
  });

  test('does not emit preserved keys when writing defaults', () {
    const String source = 'option "render_commas" "TRUE" ; keep\n';
    final String written = writeLedgerOptions(
      source,
      LedgerOptions(renderCommas: true),
      guar: const GuarOptions(writeDefaultOptions: true),
      preserveKeys: const <String>{'render_commas', 'long_string_maxlines', 'plugin_processing_mode'},
      today: DateTime(2020, 1, 2),
    );
    expect(written, contains('option "render_commas" "TRUE" ; keep'));
    expect(RegExp('render_commas').allMatches(written), hasLength(1));
    expect(written.contains('long_string_maxlines'), isFalse);
    expect(written.contains('plugin_processing_mode'), isFalse);
    expect(written.contains('option "title" "Beancount"'), isTrue);
  });

  test('drops an option line that matches the default', () {
    const String source = 'option "title" "Beancount"\n2020-01-01 open Assets:Cash\n';
    final LoadedLedgerOptions loaded = readLedgerOptions(source);
    expect(writeLedgerOptions(source, loaded.options), '2020-01-01 open Assets:Cash\n');
  });

  test('renaming equity does not emit derived account lines', () {
    final String written = writeLedgerOptions(
      '',
      LedgerOptions(accountPrefixes: const AccountPrefixes(equity: 'Capitaux')),
    );
    expect(written, 'option "name_equity" "Capitaux"\n');
  });

  test('leaves transactions, comments, and includes untouched', () {
    const String source = '; note\ninclude "child.beancount"\n\n2020-01-01 open Assets:Cash\n';
    final String written = writeLedgerOptions(source, LedgerOptions(bookingMethod: BookingMethod.fifo));
    expect(written, 'option "booking_method" "FIFO"\n$source');
  });

  test('removes a wrapped option value when it returns to the default', () {
    const String source = 'option "title" "hello\nworld"\n2020-01-01 open Assets:Cash\n';
    final LoadedLedgerOptions loaded = readLedgerOptions(source);
    expect(loaded.options.title, 'hello\nworld');
    expect(writeLedgerOptions(source, LedgerOptions()), '2020-01-01 open Assets:Cash\n');
  });

  test('refuses a quote inside an option value', () {
    expect(() => writeLedgerOptions('', LedgerOptions(title: 'say "hi"')), throwsArgumentError);
  });

  test('reads advanced_ui from a guar_option directive', () {
    expect(
      readLedgerOptions('2020-01-01 custom "guar_option" "advanced_ui" "TRUE"\n').guar.advancedUi,
      isTrue,
    );
    expect(
      readLedgerOptions('2020-01-01 custom "guar_option" "advanced_ui" TRUE\n').guar.advancedUi,
      isTrue,
    );
    expect(
      readLedgerOptions('2020-01-01 custom "guar_option" "advanced_ui" "false"\n').guar.advancedUi,
      isFalse,
    );
    const String latest =
        '2020-06-01 custom "guar_option" "advanced_ui" "TRUE"\n'
        '2020-01-01 custom "guar_option" "advanced_ui" "FALSE"\n';
    expect(readLedgerOptions(latest).guar.advancedUi, isTrue);
    const String sameDay =
        '2020-01-01 custom "guar_option" "advanced_ui" "TRUE"\n'
        '2020-01-01 custom "guar_option" "advanced_ui" "FALSE"\n';
    expect(readLedgerOptions(sameDay).guar.advancedUi, isFalse);
  });

  test('reports a bad advanced_ui value and keeps a later valid one', () {
    const String source =
        '2020-01-01 custom "guar_option" "advanced_ui" "maybe"\n'
        '2020-01-02 custom "guar_option" "advanced_ui" "true"\n';
    final LoadedLedgerOptions loaded = readLedgerOptions(source);
    expect(loaded.guar.advancedUi, isTrue);
    expect(loaded.errors, <String>['advanced_ui expects TRUE or FALSE']);
  });

  test('writes advanced_ui after option lines', () {
    final String written = writeLedgerOptions(
      '2020-01-01 open Assets:Cash\n',
      LedgerOptions(title: 'Mine'),
      guar: const GuarOptions(advancedUi: true),
      today: DateTime(2020, 1, 2),
    );
    expect(
      written,
      'option "title" "Mine"\n'
      '2020-01-02 custom "guar_option" "advanced_ui" "TRUE"\n'
      '2020-01-01 open Assets:Cash\n',
    );
    final LoadedLedgerOptions loaded = readLedgerOptions(written);
    expect(loaded.guar.advancedUi, isTrue);
    expect(loaded.options.title, 'Mine');
  });

  test('inserts advanced_ui after a wrapped option value', () {
    final String written = writeLedgerOptions(
      '',
      LedgerOptions(title: 'hello\nworld'),
      guar: const GuarOptions(advancedUi: true),
      today: DateTime(2020, 1, 2),
    );
    expect(
      written,
      'option "title" "hello\nworld"\n'
      '2020-01-02 custom "guar_option" "advanced_ui" "TRUE"\n',
    );
  });

  test('updates an existing advanced_ui line in place', () {
    const String source =
        '2020-01-01 open Assets:Cash\n'
        '2024-03-04 custom "guar_option" "advanced_ui" "FALSE"\n';
    expect(
      writeLedgerOptions(
        source,
        LedgerOptions(),
        guar: const GuarOptions(advancedUi: true),
        today: DateTime(1999),
      ),
      '2020-01-01 open Assets:Cash\n'
      '2024-03-04 custom "guar_option" "advanced_ui" "TRUE"\n',
    );
  });

  test('collapses several advanced_ui lines when the value changes', () {
    const String source =
        '2020-01-01 custom "guar_option" "advanced_ui" "FALSE"\n'
        '2020-06-01 custom "guar_option" "advanced_ui" "FALSE"\n'
        '2020-01-02 open Assets:Cash\n';
    expect(
      writeLedgerOptions(source, LedgerOptions(), guar: const GuarOptions(advancedUi: true)),
      '2020-06-01 custom "guar_option" "advanced_ui" "TRUE"\n'
      '2020-01-02 open Assets:Cash\n',
    );
  });

  test('removes advanced_ui and its metadata when turned off', () {
    const String source =
        '2020-01-01 custom "guar_option" "advanced_ui" "TRUE"\n'
        '  note: "keep"\n'
        '; comment\n'
        '2020-02-01 open Assets:Cash\n';
    expect(
      writeLedgerOptions(source, LedgerOptions(), guar: const GuarOptions()),
      '; comment\n'
      '2020-02-01 open Assets:Cash\n',
    );
  });

  test('keeps a matching advanced_ui line as written', () {
    const String source = '2020-05-01 custom "guar_option" "advanced_ui" TRUE\n';
    expect(writeLedgerOptions(source, LedgerOptions(), guar: const GuarOptions(advancedUi: true)), source);
  });

  test('reads allow_unopened_accounts from a guar_option directive', () {
    expect(
      readLedgerOptions(
        '2020-01-01 custom "guar_option" "allow_unopened_accounts" "TRUE"\n',
      ).guar.allowUnopenedAccounts,
      isTrue,
    );
    expect(
      readLedgerOptions('2020-01-01 custom "guar_option" "allow_unopened_accounts" TRUE\n').guar.allowUnopenedAccounts,
      isTrue,
    );
    expect(
      readLedgerOptions(
        '2020-01-01 custom "guar_option" "allow_unopened_accounts" "false"\n',
      ).guar.allowUnopenedAccounts,
      isFalse,
    );
    const String latest =
        '2020-06-01 custom "guar_option" "allow_unopened_accounts" "TRUE"\n'
        '2020-01-01 custom "guar_option" "allow_unopened_accounts" "FALSE"\n';
    expect(readLedgerOptions(latest).guar.allowUnopenedAccounts, isTrue);
  });

  test('reports a bad allow_unopened_accounts value', () {
    const String source = '2020-01-01 custom "guar_option" "allow_unopened_accounts" "maybe"\n';
    final LoadedLedgerOptions loaded = readLedgerOptions(source);
    expect(loaded.guar.allowUnopenedAccounts, isFalse);
    expect(loaded.errors, <String>['allow_unopened_accounts expects TRUE or FALSE']);
  });

  test('writes and removes allow_unopened_accounts like the other guar bools', () {
    final String written = writeLedgerOptions(
      '2020-01-01 open Assets:Cash\n',
      LedgerOptions(),
      guar: const GuarOptions(allowUnopenedAccounts: true),
      today: DateTime(2020, 1, 2),
    );
    expect(
      written,
      '2020-01-02 custom "guar_option" "allow_unopened_accounts" "TRUE"\n'
      '2020-01-01 open Assets:Cash\n',
    );
    expect(
      writeLedgerOptions(written, LedgerOptions(), guar: const GuarOptions(), today: DateTime(2020, 1, 2)),
      '2020-01-01 open Assets:Cash\n',
    );
  });

  test('option rewrites leave guar_option lines alone unless asked', () {
    const String source =
        '2020-01-01 custom "fava-option" "interval" "month"\n'
        '2020-02-01 custom "guar_option" "advanced_ui" "TRUE"\n'
        '2020-03-01 custom "guar_option" "theme" "dark"\n';
    expect(
      writeLedgerOptions(source, LedgerOptions(bookingMethod: BookingMethod.fifo)),
      'option "booking_method" "FIFO"\n$source',
    );
    expect(readLedgerOptions(source).guar.advancedUi, isTrue);
    expect(readLedgerOptions(source).errors, isEmpty);
    expect(
      writeLedgerOptions(source, LedgerOptions(), guar: const GuarOptions()),
      '2020-01-01 custom "fava-option" "interval" "month"\n'
      '2020-03-01 custom "guar_option" "theme" "dark"\n',
    );
  });

  test('reads write_default_options from a guar_option directive', () {
    expect(
      readLedgerOptions('2020-01-01 custom "guar_option" "write_default_options" "TRUE"\n').guar.writeDefaultOptions,
      isTrue,
    );
    expect(
      readLedgerOptions('2020-01-01 custom "guar_option" "write_default_options" TRUE\n').guar.writeDefaultOptions,
      isTrue,
    );
    expect(
      readLedgerOptions('2020-01-01 custom "guar_option" "write_default_options" "false"\n').guar.writeDefaultOptions,
      isFalse,
    );
    const String latest =
        '2020-06-01 custom "guar_option" "write_default_options" "TRUE"\n'
        '2020-01-01 custom "guar_option" "write_default_options" "FALSE"\n';
    expect(readLedgerOptions(latest).guar.writeDefaultOptions, isTrue);
    const String sameDay =
        '2020-01-01 custom "guar_option" "write_default_options" "TRUE"\n'
        '2020-01-01 custom "guar_option" "write_default_options" "FALSE"\n';
    expect(readLedgerOptions(sameDay).guar.writeDefaultOptions, isFalse);
  });

  test('reports a bad write_default_options value and keeps a later valid one', () {
    const String source =
        '2020-01-01 custom "guar_option" "advanced_ui" "maybe"\n'
        '2020-01-02 custom "guar_option" "write_default_options" "maybe"\n'
        '2020-01-03 custom "guar_option" "write_default_options" "true"\n';
    final LoadedLedgerOptions loaded = readLedgerOptions(source);
    expect(loaded.guar.advancedUi, isFalse);
    expect(loaded.guar.writeDefaultOptions, isTrue);
    expect(loaded.errors, <String>[
      'advanced_ui expects TRUE or FALSE',
      'write_default_options expects TRUE or FALSE',
    ]);
  });

  test('writes default option lines when write_default_options is on', () {
    final List<String> lines = explicitOptionLines(LedgerOptions(), writeDefaults: true);
    expect(lines, hasLength(20));
    expect(lines, contains('option "title" "Beancount"'));
    expect(lines, contains('option "conversion_currency" "NOTHING"'));
    expect(lines, contains('option "render_commas" "FALSE"'));
    expect(lines, contains('option "plugin_processing_mode" "DEFAULT"'));
    expect(lines, contains('option "name_assets" "Assets"'));
    expect(lines, contains('option "account_previous_balances" "Equity:Opening-Balances"'));
    expect(lines, contains('option "account_unrealized_gains" "Income:Earnings:Unrealized"'));
    expect(lines, contains('option "booking_method" "STRICT"'));
    expect(lines, contains('option "tolerance_multiplier" "0.5"'));
    expect(lines.any((String line) => line.contains('insert_pythonpath')), isFalse);
    expect(lines.any((String line) => line.contains('allow_pipe_separator')), isFalse);
    expect(lines.any((String line) => line.contains('allow_deprecated_none')), isFalse);
    expect(lines.any((String line) => line.contains('inferred_tolerance_multiplier')), isFalse);
    expect(lines.any((String line) => line.contains('account_rounding')), isFalse);

    final String written = writeLedgerOptions(
      '2020-01-01 open Assets:Cash\n',
      LedgerOptions(title: 'Mine', bookingMethod: BookingMethod.fifo),
      guar: const GuarOptions(writeDefaultOptions: true),
      today: DateTime(2020, 1, 2),
    );
    expect(written.contains('option "title" "Mine"'), isTrue);
    expect(written.contains('option "booking_method" "FIFO"'), isTrue);
    expect(written.contains('option "title" "Beancount"'), isFalse);
    expect(written.contains('option "name_equity" "Equity"'), isTrue);
    expect(written.contains('insert_pythonpath'), isFalse);
    expect(
      written.endsWith(
        '2020-01-02 custom "guar_option" "write_default_options" "TRUE"\n'
        '2020-01-01 open Assets:Cash\n',
      ),
      isTrue,
    );
    final LoadedLedgerOptions loaded = readLedgerOptions(written);
    expect(loaded.errors, isEmpty);
    expect(loaded.guar.writeDefaultOptions, isTrue);
    expect(loaded.options.title, 'Mine');
    expect(loaded.options.bookingMethod, BookingMethod.fifo);
    expect(writeLedgerOptions(written, loaded.options, guar: loaded.guar, today: DateTime(1999)), written);
  });

  test('write_default_options includes accounts implied by a renamed prefix', () {
    final String written = writeLedgerOptions(
      '',
      LedgerOptions(accountPrefixes: const AccountPrefixes(equity: 'Capitaux')),
      guar: const GuarOptions(writeDefaultOptions: true),
      today: DateTime(2020, 1, 2),
    );
    expect(written.contains('option "name_equity" "Capitaux"'), isTrue);
    expect(written.contains('option "account_previous_balances" "Capitaux:Opening-Balances"'), isTrue);
    expect(written.contains('option "account_unrealized_gains" "Income:Earnings:Unrealized"'), isTrue);
  });

  test('turning write_default_options off drops default lines and the custom directive', () {
    const String source =
        'option "title" "Beancount"\n'
        'option "booking_method" "FIFO"\n'
        '2020-01-02 custom "guar_option" "write_default_options" "TRUE"\n'
        '  note: "keep"\n'
        '2020-01-01 open Assets:Cash\n';
    expect(
      writeLedgerOptions(source, LedgerOptions(bookingMethod: BookingMethod.fifo), guar: const GuarOptions()),
      'option "booking_method" "FIFO"\n'
      '2020-01-01 open Assets:Cash\n',
    );
  });

  test('keeps a matching write_default_options line and still fills defaults', () {
    const String source = '2020-05-01 custom "guar_option" "write_default_options" TRUE\n';
    final String written = writeLedgerOptions(
      source,
      LedgerOptions(),
      guar: const GuarOptions(writeDefaultOptions: true),
    );
    expect(written.endsWith(source), isTrue);
    expect(written.contains('option "title" "Beancount"'), isTrue);
  });

  test('advanced_ui and write_default_options are written independently', () {
    final String written = writeLedgerOptions(
      '',
      LedgerOptions(),
      guar: const GuarOptions(advancedUi: true, writeDefaultOptions: true),
      today: DateTime(2020, 1, 2),
    );
    expect(
      written.endsWith(
        '2020-01-02 custom "guar_option" "advanced_ui" "TRUE"\n'
        '2020-01-02 custom "guar_option" "write_default_options" "TRUE"\n',
      ),
      isTrue,
    );
    final String advancedOff = writeLedgerOptions(
      written,
      LedgerOptions(),
      guar: const GuarOptions(writeDefaultOptions: true),
      today: DateTime(1999),
    );
    expect(advancedOff.contains('advanced_ui'), isFalse);
    expect(advancedOff.contains('write_default_options'), isTrue);
    expect(advancedOff.contains('option "title" "Beancount"'), isTrue);
  });

  test('honors one quoted TRUE toggle per directive', () {
    const String source =
        '2020-05-01 custom "guar_option" "hide_price" "TRUE"\n'
        '  note: "keep"\n'
        '2020-05-02 custom "guar_option" "hide_generated" "TRUE"\n';
    final LoadedLedgerOptions loaded = readLedgerOptions(source);
    expect(loaded.errors, isEmpty);
    expect(loaded.guar.hidden, <String>{'price', 'generated'});
    expect(writeLedgerOptions(source, LedgerOptions(), guar: loaded.guar, today: DateTime(1999)), source);
  });

  test('does not honor a hide line that is not the toggle format', () {
    const String quoted = '2020-01-01 custom "guar_option" "hide_price" "true"\n';
    final LoadedLedgerOptions lower = readLedgerOptions(quoted);
    expect(lower.guar.hidden, isEmpty);
    expect(lower.errors, <String>['hide_price: found "true" expected "TRUE"']);
    expect(writeLedgerOptions(quoted, LedgerOptions(), guar: const GuarOptions()), quoted);

    const String bare = '2020-01-01 custom "guar_option" "hide_price" TRUE\n';
    final LoadedLedgerOptions unquoted = readLedgerOptions(bare);
    expect(unquoted.guar.hidden, isEmpty);
    expect(unquoted.errors, <String>['hide_price: found TRUE expected "TRUE"']);
    expect(writeLedgerOptions(bare, LedgerOptions(), guar: const GuarOptions()), bare);

    const String list =
        '2020-03-01 custom "guar_option" "theme" "dark"\n'
        '2020-02-01 custom "guar_option" "hide_directives" "price" "note"\n'
        '  note: "keep"\n'
        '2020-04-01 open Assets:Cash\n';
    final LoadedLedgerOptions freeform = readLedgerOptions(list);
    expect(freeform.guar.hidden, isEmpty);
    expect(freeform.errors, <String>['hide_directives is not a ledger hide toggle']);
    expect(writeLedgerOptions(list, LedgerOptions(), guar: const GuarOptions()), list);
    expect(
      writeLedgerOptions(list, LedgerOptions(bookingMethod: BookingMethod.fifo)),
      'option "booking_method" "FIFO"\n$list',
    );
  });

  test('does not honor repeated hide toggles', () {
    const String source =
        '2020-01-01 custom "guar_option" "hide_open" "TRUE"\n'
        '2020-06-01 custom "guar_option" "hide_open" "TRUE"\n';
    final LoadedLedgerOptions loaded = readLedgerOptions(source);
    expect(loaded.guar.hidden, isEmpty);
    expect(loaded.errors, <String>['hide_open expects a single "TRUE"']);
    expect(writeLedgerOptions(source, LedgerOptions(), guar: const GuarOptions()), source);
  });

  test('writes a hide toggle after other guar options', () {
    final String written = writeLedgerOptions(
      '2020-01-02 custom "guar_option" "advanced_ui" "TRUE"\n',
      LedgerOptions(),
      guar: const GuarOptions(advancedUi: true, hidden: <String>{'note', 'generated'}),
      today: DateTime(1999),
    );
    expect(
      written,
      '2020-01-02 custom "guar_option" "advanced_ui" "TRUE"\n'
      '1999-01-01 custom "guar_option" "hide_generated" "TRUE"\n'
      '1999-01-01 custom "guar_option" "hide_note" "TRUE"\n',
    );
    final LoadedLedgerOptions loaded = readLedgerOptions(written);
    expect(loaded.errors, isEmpty);
    expect(loaded.guar.hidden, <String>{'generated', 'note'});
    expect(writeLedgerOptions(written, loaded.options, guar: loaded.guar, today: DateTime(2024)), written);
  });

  test('replaces an inexact hide toggle when that switch is turned on', () {
    const String source =
        '2020-01-01 custom "guar_option" "hide_price" "true"\n'
        '  note: "keep"\n'
        '2020-02-01 open Assets:Cash\n';
    expect(
      writeLedgerOptions(
        source,
        LedgerOptions(),
        guar: const GuarOptions(hidden: <String>{'price'}),
        today: DateTime(1999),
      ),
      '2020-01-01 custom "guar_option" "hide_price" "TRUE"\n'
      '2020-02-01 open Assets:Cash\n',
    );
  });

  test('removes an exact hide toggle when that switch is turned off', () {
    const String source =
        '2020-05-01 custom "guar_option" "hide_price" "TRUE"\n'
        '  note: "keep"\n'
        '2020-02-01 open Assets:Cash\n';
    expect(
      writeLedgerOptions(source, LedgerOptions(), guar: const GuarOptions()),
      '2020-02-01 open Assets:Cash\n',
    );
  });

  test('advanced_ui, write_default_options, and hide toggles are written together', () {
    final String written = writeLedgerOptions(
      '',
      LedgerOptions(),
      guar: const GuarOptions(advancedUi: true, writeDefaultOptions: true, hidden: <String>{'balance'}),
      today: DateTime(2020, 1, 2),
    );
    expect(
      written.endsWith(
        '2020-01-02 custom "guar_option" "advanced_ui" "TRUE"\n'
        '2020-01-02 custom "guar_option" "write_default_options" "TRUE"\n'
        '2020-01-02 custom "guar_option" "hide_balance" "TRUE"\n',
      ),
      isTrue,
    );
  });

  test('reads language from a guar_option directive', () {
    expect(
      readLedgerOptions('2020-01-01 custom "guar_option" "language" "fr"\n').guar.language,
      'fr',
    );
    expect(readLedgerOptions('2020-01-01 open Assets:Cash\n').guar.language, isNull);
    const String latest =
        '2020-01-01 custom "guar_option" "language" "fr"\n'
        '2020-06-01 custom "guar_option" "language" "de"\n';
    expect(readLedgerOptions(latest).guar.language, 'de');
  });

  test('reports a missing language value', () {
    expect(
      readLedgerOptions('2020-01-01 custom "guar_option" "language"\n').errors,
      <String>['language expects a language code'],
    );
    expect(
      readLedgerOptions('2020-01-01 custom "guar_option" "language" 3\n').errors,
      <String>['language expects a language code'],
    );
  });

  test('writes language after the other guar options', () {
    final String written = writeLedgerOptions(
      '',
      LedgerOptions(),
      guar: const GuarOptions(language: 'fr'),
      today: DateTime(2020, 1, 2),
    );
    expect(written, '2020-01-02 custom "guar_option" "language" "fr"\n');
    expect(readLedgerOptions(written).guar.language, 'fr');
  });

  test('updates an existing language line in place', () {
    const String source =
        '2020-01-01 custom "guar_option" "language" "fr"\n'
        '2020-02-01 open Assets:Cash\n';
    final String written = writeLedgerOptions(
      source,
      LedgerOptions(),
      guar: const GuarOptions(language: 'de'),
    );
    expect(
      written,
      '2020-01-01 custom "guar_option" "language" "de"\n'
      '2020-02-01 open Assets:Cash\n',
    );
  });

  test('removes the language line when the option is cleared', () {
    const String source =
        '2020-01-01 custom "guar_option" "language" "fr"\n'
        '2020-02-01 open Assets:Cash\n';
    expect(
      writeLedgerOptions(source, LedgerOptions(), guar: const GuarOptions()),
      '2020-02-01 open Assets:Cash\n',
    );
  });

  test('keeps a matching language line as written', () {
    const String source = '2020-05-01 custom "guar_option" "language" "fr"\n';
    expect(writeLedgerOptions(source, LedgerOptions(), guar: const GuarOptions(language: 'fr')), source);
  });
}
