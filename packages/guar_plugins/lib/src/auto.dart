// Meta-plugin: auto_accounts then implicit_prices.

import 'plugin.dart';
import 'auto_accounts.dart';
import 'combine.dart';
import 'implicit_prices.dart';

final BookPlugin autoPlugin = combinePlugins([autoInsertOpen, addImplicitPrices]);
