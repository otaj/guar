// Default map of beancount_reds_plugins module names to Dart BookPlugin implementations.

import '../../plugin.dart';
import '../close_tree.dart';

final Map<String, BookPlugin> redsPlugins = {'beancount_reds_plugins.autoclose_tree.autoclose_tree': closeTree};
