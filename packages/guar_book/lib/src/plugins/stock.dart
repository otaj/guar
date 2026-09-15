// Default map of beancount.plugins.* names to Dart BookPlugin implementations.

import '../plugin.dart';
import 'auto_accounts.dart';

final Map<String, BookPlugin> stockPlugins = {'beancount.plugins.auto_accounts': autoInsertOpen};
