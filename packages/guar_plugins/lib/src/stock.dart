// Default map of beancount.plugins.* names to Dart BookPlugin implementations.

import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/plugin_info.dart';
import 'package:guar_plugins/src/stock_catalog.dart';

final Map<String, BookPlugin> stockPlugins = <String, BookPlugin>{
  for (final PluginDeclaration plugin in stockCatalog) plugin.name: plugin.apply,
};
