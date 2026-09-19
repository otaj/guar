// Meta-plugin bundling every strict stock validation in one directive.

import 'package:guar_plugins/src/check_commodity.dart';
import 'package:guar_plugins/src/check_drained.dart';
import 'package:guar_plugins/src/coherent_cost.dart';
import 'package:guar_plugins/src/combine.dart';
import 'package:guar_plugins/src/leafonly.dart';
import 'package:guar_plugins/src/noduplicates.dart';
import 'package:guar_plugins/src/nounused.dart';
import 'package:guar_plugins/src/onecommodity.dart';
import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/sellgains.dart';
import 'package:guar_plugins/src/unique_prices.dart';

final BookPlugin pedanticPlugin = combinePlugins(<BookPlugin>[
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
