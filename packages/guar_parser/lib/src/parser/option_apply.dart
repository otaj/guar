// Applies a parsed option key/value onto LedgerOptions.

import 'package:decimal/decimal.dart';
import 'package:petitparser/petitparser.dart';

import '../domain/domain.dart';
import 'tokens.dart';

(LedgerOptions, String?) applyLedgerOption(LedgerOptions options, String key, String value) {
  switch (key) {
    case 'title':
      return (options.copyWith(title: value), null);
    case 'documents':
      return (options.copyWith(documents: [...options.documents, value]), null);
    case 'operating_currency':
      if (!isValidCurrencyName(value)) {
        return (options, 'unknown option');
      }
      return (
        options.copyWith(
          operatingCurrency: [
            ...options.operatingCurrency,
            Currency(name: value),
          ],
        ),
        null,
      );
    case 'conversion_currency':
      if (!isValidCurrencyName(value)) {
        return (options, 'unknown option');
      }
      return (options.copyWith(conversionCurrency: Currency(name: value)), null);
    case 'render_commas':
      return _boolOption(options, value, (parsed) => options.copyWith(renderCommas: parsed));
    case 'use_precise_interpolation':
      return _boolOption(options, value, (parsed) => options.copyWith(usePreciseInterpolation: parsed));
    case 'infer_tolerance_from_cost':
      return _boolOption(options, value, (parsed) => options.copyWith(inferToleranceFromCost: parsed));
    case 'insert_pythonpath':
      return _boolOption(options, value, (parsed) => options.copyWith(insertPythonpath: parsed));
    case 'allow_pipe_separator':
      return _boolOption(options, value, (parsed) => options.copyWith(allowPipeSeparator: parsed));
    case 'allow_deprecated_none_for_tags_and_links':
      return _boolOption(options, value, (parsed) => options.copyWith(allowDeprecatedNoneForTagsAndLinks: parsed));
    case 'plugin_processing_mode':
      final mode = switch (value.toUpperCase()) {
        'DEFAULT' => PluginProcessingMode.defaultMode,
        'RAW' => PluginProcessingMode.raw,
        _ => null,
      };
      if (mode == null) {
        return (options, 'Expected one of DEFAULT, RAW');
      }
      return (options.copyWith(pluginProcessingMode: mode), null);
    case 'booking_method':
      final method = _parseBookingMethod(value);
      if (method == null) {
        return (options, 'Expected one of STRICT, STRICT_WITH_SIZE, NONE, AVERAGE, FIFO, LIFO, HIFO');
      }
      return (options.copyWith(bookingMethod: method), null);
    case 'inferred_tolerance_default':
    case 'default_tolerance':
      final tolerance = _parseInferredTolerance(value);
      if (tolerance == null) {
        return (options, 'unknown option');
      }
      final next = [...options.inferredToleranceDefault, tolerance]..sort(_compareInferredTolerance);
      return (options.copyWith(inferredToleranceDefault: next), null);
    case 'inferred_tolerance_multiplier':
      final number = _parseBeanNumber(value);
      if (number == null) {
        return (options, 'unknown option');
      }
      return (options.copyWith(inferredToleranceMultiplier: number), null);
    case 'tolerance_multiplier':
      final number = _parseBeanNumber(value);
      if (number == null) {
        return (options, 'unknown option');
      }
      return (options.copyWith(toleranceMultiplier: number), null);
    case 'display_precision':
      final precision = _parseDisplayPrecision(value);
      if (precision == null) {
        return (options, 'unknown option');
      }
      final next = [...options.displayPrecision, precision];
      return (options.copyWith(displayPrecision: next), null);
    case 'long_string_maxlines':
      final parsed = int.tryParse(value.trim());
      if (parsed == null || parsed < 0) {
        return (options, 'unknown option');
      }
      return (options.copyWith(longStringMaxlines: parsed), null);
    case 'name_assets':
      return (options.copyWith(accountPrefixes: options.accountPrefixes.copyWith(assets: value)), null);
    case 'name_liabilities':
      return (options.copyWith(accountPrefixes: options.accountPrefixes.copyWith(liabilities: value)), null);
    case 'name_equity':
      return (options.copyWith(accountPrefixes: options.accountPrefixes.copyWith(equity: value)), null);
    case 'name_income':
      return (options.copyWith(accountPrefixes: options.accountPrefixes.copyWith(income: value)), null);
    case 'name_expenses':
      return (options.copyWith(accountPrefixes: options.accountPrefixes.copyWith(expenses: value)), null);
    case 'account_previous_balances':
      return _accountOption(options, value, (account) => options.copyWith(accountPreviousBalances: account));
    case 'account_previous_earnings':
      return _accountOption(options, value, (account) => options.copyWith(accountPreviousEarnings: account));
    case 'account_previous_conversions':
      return _accountOption(options, value, (account) => options.copyWith(accountPreviousConversions: account));
    case 'account_current_earnings':
      return _accountOption(options, value, (account) => options.copyWith(accountCurrentEarnings: account));
    case 'account_current_conversions':
      return _accountOption(options, value, (account) => options.copyWith(accountCurrentConversions: account));
    case 'account_rounding':
      return _accountOption(options, value, (account) => options.copyWith(accountRounding: account));
    case 'account_unrealized_gains':
      return _accountOption(
        options,
        value,
        (account) => options.copyWith(accountUnrealizedGains: account),
        root: options.accountPrefixes.income ?? 'Income',
      );
    default:
      return (options, 'unknown option');
  }
}

LedgerOptions replayLedgerOptions(Iterable<OptionSetting> settings) {
  var options = LedgerOptions();
  for (final setting in settings) {
    final applied = applyLedgerOption(options, setting.key, setting.value);
    if (applied.$2 != null) {
      continue;
    }
    options = applied.$1;
  }
  return options;
}

(LedgerOptions, String?) _boolOption(LedgerOptions options, String value, LedgerOptions Function(bool parsed) apply) {
  final parsed = _parseOptionBool(value);
  if (parsed == null) {
    return (options, 'unknown option');
  }
  return (apply(parsed), null);
}

(LedgerOptions, String?) _accountOption(
  LedgerOptions options,
  String value,
  LedgerOptions Function(Account account) apply, {
  String? root,
}) {
  final account = _optionAccount(options, value, root: root);
  if (account == null) {
    return (options, 'unknown option');
  }
  return (apply(account), null);
}

Account? _optionAccount(LedgerOptions options, String value, {String? root}) {
  final prefix = root ?? options.accountPrefixes.equity ?? 'Equity';
  final name = value.contains(':') ? value : '$prefix:$value';
  if (!isValidAccountName(name)) {
    return null;
  }
  return Account(name: name);
}

bool? _parseOptionBool(String value) {
  switch (value.toLowerCase()) {
    case 'true':
    case '1':
      return true;
    case 'false':
    case '0':
      return false;
    default:
      return null;
  }
}

BookingMethod? _parseBookingMethod(String value) {
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

BeanNumber? _parseBeanNumber(String value) {
  final number = numberExpr().parse(value);
  if (number is Success && number.position == value.length) {
    return number.value;
  }
  try {
    return BeanNumber(verbatim: value, resolved: Decimal.parse(value));
  } catch (_) {
    return null;
  }
}

DisplayPrecision? _parseDisplayPrecision(String value) {
  final colon = value.indexOf(':');
  if (colon <= 0 || colon == value.length - 1) {
    return null;
  }
  final key = _parseDisplayPrecisionKey(value.substring(0, colon));
  final number = _parseBeanNumber(value.substring(colon + 1));
  if (key == null || number == null) {
    return null;
  }
  return DisplayPrecision(key: key, value: number);
}

DisplayPrecisionKey? _parseDisplayPrecisionKey(String text) {
  if (text == '*') {
    return const DisplayPrecisionKey.all();
  }
  final slash = text.indexOf('/');
  if (slash > 0 && slash < text.length - 1) {
    final first = text.substring(0, slash);
    final second = text.substring(slash + 1);
    if (!isValidCurrencyName(first) || !isValidCurrencyName(second)) {
      return null;
    }
    return DisplayPrecisionKey.pair(
      first: Currency(name: first),
      second: Currency(name: second),
    );
  }
  if (!isValidCurrencyName(text)) {
    return null;
  }
  return DisplayPrecisionKey.currency(Currency(name: text));
}

InferredTolerance? _parseInferredTolerance(String value) {
  final colon = value.indexOf(':');
  if (colon <= 0 || colon == value.length - 1) {
    return null;
  }
  final keyText = value.substring(0, colon);
  final numberText = value.substring(colon + 1);
  final number = _parseBeanNumber(numberText);
  if (number == null) {
    return null;
  }
  if (keyText == '*') {
    return InferredTolerance(key: const CurrencyKey.all(), value: number);
  }
  if (!isValidCurrencyName(keyText)) {
    return null;
  }
  return InferredTolerance(
    key: CurrencyKey.currency(Currency(name: keyText)),
    value: number,
  );
}

int _compareInferredTolerance(InferredTolerance a, InferredTolerance b) {
  return _toleranceKeySort(a.key).compareTo(_toleranceKeySort(b.key));
}

String _toleranceKeySort(CurrencyKey key) {
  return switch (key) {
    CurrencyKeyAll() => '*',
    CurrencyKeyCurrency(:final value) => value.name,
  };
}
