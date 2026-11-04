// Combined default plugin map registered by Book().

import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/plugin_info.dart';
import 'package:guar_plugins/src/reds/reds.dart';
import 'package:guar_plugins/src/reds_catalog.dart';
import 'package:guar_plugins/src/stock.dart';
import 'package:guar_plugins/src/stock_catalog.dart';

final List<PluginDeclaration> pluginCatalog = List<PluginDeclaration>.unmodifiable(<PluginDeclaration>[
  ...stockCatalog,
  ...redsCatalog,
]);

final Map<String, BookPlugin> defaultPlugins = <String, BookPlugin>{...stockPlugins, ...redsPlugins};
