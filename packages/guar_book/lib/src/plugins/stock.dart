// Default map of beancount.plugins.* names to Dart BookPlugin implementations.

import '../plugin.dart';
import 'auto.dart';
import 'auto_accounts.dart';
import 'check_average_cost.dart';
import 'check_closing.dart';
import 'check_commodity.dart';
import 'check_drained.dart';
import 'close_tree.dart';
import 'coherent_cost.dart';
import 'commodity_attr.dart';
import 'currency_accounts.dart';
import 'implicit_prices.dart';
import 'leafonly.dart';
import 'noduplicates.dart';
import 'nounused.dart';
import 'onecommodity.dart';
import 'pedantic.dart';
import 'sellgains.dart';
import 'unique_prices.dart';

final Map<String, BookPlugin> stockPlugins = {
  'beancount.plugins.auto': autoPlugin,
  'beancount.plugins.auto_accounts': autoInsertOpen,
  'beancount.plugins.check_average_cost': validateAverageCost,
  'beancount.plugins.check_closing': checkClosing,
  'beancount.plugins.check_commodity': validateCommodityDirectives,
  'beancount.plugins.check_drained': checkDrained,
  'beancount.plugins.close_tree': closeTree,
  'beancount.plugins.coherent_cost': validateCoherentCost,
  'beancount.plugins.commodity_attr': validateCommodityAttr,
  'beancount.plugins.currency_accounts': insertCurrencyTradingPostings,
  'beancount.plugins.implicit_prices': addImplicitPrices,
  'beancount.plugins.leafonly': validateLeafOnly,
  'beancount.plugins.noduplicates': validateNoDuplicates,
  'beancount.plugins.nounused': validateUnusedAccounts,
  'beancount.plugins.onecommodity': validateOneCommodity,
  'beancount.plugins.pedantic': pedanticPlugin,
  'beancount.plugins.sellgains': validateSellGains,
  'beancount.plugins.unique_prices': validateUniquePrices,
};
