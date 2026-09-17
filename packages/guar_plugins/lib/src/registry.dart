// Combined default plugin map registered by Book().

import 'plugin.dart';
import 'reds/reds.dart';
import 'stock.dart';

final Map<String, BookPlugin> defaultPlugins = {...stockPlugins, ...redsPlugins};
