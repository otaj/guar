// Default map of beancount.plugins.* names to Dart BookPlugin implementations.

import 'package:guar_plugins/src/auto.dart';
import 'package:guar_plugins/src/auto_accounts.dart';
import 'package:guar_plugins/src/check_average_cost.dart';
import 'package:guar_plugins/src/check_closing.dart';
import 'package:guar_plugins/src/check_commodity.dart';
import 'package:guar_plugins/src/check_drained.dart';
import 'package:guar_plugins/src/close_tree.dart';
import 'package:guar_plugins/src/coherent_cost.dart';
import 'package:guar_plugins/src/commodity_attr.dart';
import 'package:guar_plugins/src/currency_accounts.dart';
import 'package:guar_plugins/src/implicit_prices.dart';
import 'package:guar_plugins/src/leafonly.dart';
import 'package:guar_plugins/src/noduplicates.dart';
import 'package:guar_plugins/src/nounused.dart';
import 'package:guar_plugins/src/onecommodity.dart';
import 'package:guar_plugins/src/pedantic.dart';
import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/sellgains.dart';
import 'package:guar_plugins/src/unique_prices.dart';

final Map<String, BookPlugin> stockPlugins = <String, BookPlugin>{
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
