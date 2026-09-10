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
      return (
        options.copyWith(
          operatingCurrency: [
            ...options.operatingCurrency,
            Currency(name: value),
          ],
        ),
        null,
      );
    case 'render_commas':
      final parsed = _parseOptionBool(value);
      if (parsed == null) {
        return (options, 'unknown option');
      }
      return (options.copyWith(renderCommas: parsed), null);
    case 'plugin_processing_mode':
      final mode = switch (value) {
        'DEFAULT' => PluginProcessingMode.defaultMode,
        'RAW' => PluginProcessingMode.raw,
        _ => null,
      };
      if (mode == null) {
        return (options, 'Expected one of DEFAULT, RAW');
      }
      return (options.copyWith(pluginProcessingMode: mode), null);
    case 'inferred_tolerance_default':
      final tolerance = _parseInferredTolerance(value);
      if (tolerance == null) {
        return (options, 'unknown option');
      }
      final next = [...options.inferredToleranceDefault, tolerance]..sort(_compareInferredTolerance);
      return (options.copyWith(inferredToleranceDefault: next), null);
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
    default:
      return (options, 'unknown option');
  }
}

LedgerOptions replayLedgerOptions(Iterable<OptionSetting> settings) {
  var options = const LedgerOptions();
  for (final setting in settings) {
    final applied = applyLedgerOption(options, setting.key, setting.value);
    if (applied.$2 != null) {
      continue;
    }
    options = applied.$1;
  }
  return options;
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

InferredTolerance? _parseInferredTolerance(String value) {
  final colon = value.indexOf(':');
  if (colon <= 0 || colon == value.length - 1) {
    return null;
  }
  final keyText = value.substring(0, colon);
  final numberText = value.substring(colon + 1);
  final number = numberExpr().parse(numberText);
  if (number is! Success || number.position != numberText.length) {
    try {
      return InferredTolerance(
        key: keyText == '*' ? const CurrencyKey.all() : CurrencyKey.currency(Currency(name: keyText)),
        value: BeanNumber(verbatim: numberText, resolved: Decimal.parse(numberText)),
      );
    } catch (_) {
      return null;
    }
  }
  return InferredTolerance(
    key: keyText == '*' ? const CurrencyKey.all() : CurrencyKey.currency(Currency(name: keyText)),
    value: number.value,
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
