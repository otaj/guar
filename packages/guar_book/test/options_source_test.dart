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
}
