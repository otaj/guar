// Meta-plugin: auto_accounts then implicit_prices.

import 'package:guar_plugins/src/auto_accounts.dart';
import 'package:guar_plugins/src/combine.dart';
import 'package:guar_plugins/src/implicit_prices.dart';
import 'package:guar_plugins/src/plugin.dart';

final BookPlugin autoPlugin = combinePlugins(<BookPlugin>[autoInsertOpen, addImplicitPrices]);
