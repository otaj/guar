// Meta-plugin bundling every strict stock validation in one directive.

import 'plugin.dart';
import 'check_commodity.dart';
import 'check_drained.dart';
import 'coherent_cost.dart';
import 'combine.dart';
import 'leafonly.dart';
import 'noduplicates.dart';
import 'nounused.dart';
import 'onecommodity.dart';
import 'sellgains.dart';
import 'unique_prices.dart';

final BookPlugin pedanticPlugin = combinePlugins([
  validateCommodityDirectives,
  validateCoherentCost,
  validateLeafOnly,
  validateNoDuplicates,
  validateUnusedAccounts,
  validateOneCommodity,
  validateSellGains,
  validateUniquePrices,
  checkDrained,
]);
