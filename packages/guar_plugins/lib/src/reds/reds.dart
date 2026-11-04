// Default map of beancount_reds_plugins module names to Dart BookPlugin implementations.

import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/plugin_info.dart';
import 'package:guar_plugins/src/reds_catalog.dart';

final Map<String, BookPlugin> redsPlugins = <String, BookPlugin>{
  for (final PluginDeclaration plugin in redsCatalog) plugin.name: plugin.apply,
};
