// Default map of beancount.plugins.* names to Dart BookPlugin implementations.

import '../plugin.dart';
import 'auto.dart';
import 'auto_accounts.dart';
import 'implicit_prices.dart';
import 'noduplicates.dart';
import 'nounused.dart';
import 'onecommodity.dart';
import 'unique_prices.dart';

final Map<String, BookPlugin> stockPlugins = {
  'beancount.plugins.auto': autoPlugin,
  'beancount.plugins.auto_accounts': autoInsertOpen,
  'beancount.plugins.implicit_prices': addImplicitPrices,
  'beancount.plugins.noduplicates': validateNoDuplicates,
  'beancount.plugins.nounused': validateUnusedAccounts,
  'beancount.plugins.onecommodity': validateOneCommodity,
  'beancount.plugins.unique_prices': validateUniquePrices,
};
