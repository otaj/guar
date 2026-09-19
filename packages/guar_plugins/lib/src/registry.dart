// Combined default plugin map registered by Book().

import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/reds/reds.dart';
import 'package:guar_plugins/src/stock.dart';

final Map<String, BookPlugin> defaultPlugins = <String, BookPlugin>{...stockPlugins, ...redsPlugins};
