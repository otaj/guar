// Stock Beancount plugins in registry order, with the text the app shows.

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
import 'package:guar_plugins/src/plugin_codecs.dart';
import 'package:guar_plugins/src/plugin_info.dart';
import 'package:guar_plugins/src/sellgains.dart';
import 'package:guar_plugins/src/unique_prices.dart';

final List<PluginDeclaration> stockCatalog = <PluginDeclaration>[
  PluginDeclaration(
    name: 'beancount.plugins.auto',
    description:
        'Runs auto_accounts and then implicit_prices, so accounts are opened and prices are filled in from transactions.',
    apply: autoPlugin,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.auto_accounts',
    description: 'Inserts an open directive for every account that is used before it is opened.',
    apply: autoInsertOpen,
  ),
  PluginDeclaration(
    name: 'beancount.plugins.check_average_cost',
    description:
        'For accounts booked NONE, checks that a reducing posting stays near the running average cost. '
        'The tolerance is a fraction of that average.',
    apply: validateAverageCost,
    setup: averageCostSetup,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.check_closing',
    description: 'Turns a posting marked closing: TRUE into a balance assertion of zero for that account.',
    apply: checkClosing,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.check_commodity',
    description:
        'Requires a commodity directive for every currency the ledger uses. '
        'Each row is an account pattern and a commodity pattern to ignore.',
    apply: validateCommodityDirectives,
    setup: commodityCheckSetup,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.check_drained',
    description: 'After a balance-sheet account is closed, asserts that its balance is zero the next day.',
    apply: checkDrained,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.close_tree',
    description: 'When an account is closed, also closes every descendant that is still open.',
    apply: closeTree,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.coherent_cost',
    description: 'Rejects a commodity that is posted both with a cost and without one.',
    apply: validateCoherentCost,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.commodity_attr',
    description:
        'Requires commodity directives to carry metadata. '
        'List the values that are allowed, or leave them empty to require the attribute with any value.',
    apply: validateCommodityAttr,
    setup: commodityAttrSetup,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.currency_accounts',
    description:
        'Splits a transaction that converts currencies so each currency balances, '
        'and posts the difference under a base account.',
    apply: insertCurrencyTradingPostings,
    setup: currencyAccountsSetup,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.implicit_prices',
    description: 'Adds price directives from posting prices and from costs that increase a position.',
    apply: addImplicitPrices,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.leafonly',
    description: 'Rejects a posting to an account that has child accounts.',
    apply: validateLeafOnly,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.noduplicates',
    description:
        'Rejects two directives that are the same once metadata is ignored. Repeated price directives are allowed.',
    apply: validateNoDuplicates,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.nounused',
    description: 'Reports an account that is opened and never used again.',
    apply: validateUnusedAccounts,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.onecommodity',
    description:
        'Each account may use only one units currency and one cost currency. '
        'The pattern limits which accounts are checked.',
    apply: validateOneCommodity,
    setup: oneCommoditySetup,
  ),
  PluginDeclaration(
    name: 'beancount.plugins.pedantic',
    description:
        'Runs the strict checks together: check_commodity, coherent_cost, leafonly, noduplicates, '
        'nounused, onecommodity, sellgains, unique_prices, and check_drained.',
    apply: pedanticPlugin,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.sellgains',
    description: 'Checks that a sale at a price matches the other legs of the transaction.',
    apply: validateSellGains,
  ),
  const PluginDeclaration(
    name: 'beancount.plugins.unique_prices',
    description: 'Rejects two different prices for the same day and currency pair.',
    apply: validateUniquePrices,
  ),
];
