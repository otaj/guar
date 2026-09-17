// Default map of beancount_reds_plugins module names to Dart BookPlugin implementations.

import '../plugin.dart';
import '../close_tree.dart';
import 'box_accrual.dart';
import 'daf_mirror.dart';
import 'effective_date.dart';
import 'gain_loss.dart';
import 'long_short.dart';
import 'opengroup.dart';
import 'rename_accounts.dart';
import 'zerosum.dart';

final Map<String, BookPlugin> redsPlugins = {
  'beancount_reds_plugins.autoclose_tree.autoclose_tree': closeTree,
  'beancount_reds_plugins.box_accrual.box_accrual': boxAccrual,
  'beancount_reds_plugins.capital_gains_classifier.gain_loss': gainLoss,
  'beancount_reds_plugins.capital_gains_classifier.long_short': longShort,
  'beancount_reds_plugins.daf.daf_mirror': dafMirror,
  'beancount_reds_plugins.effective_date.effective_date': effectiveDate,
  'beancount_reds_plugins.opengroup.opengroup': opengroup,
  'beancount_reds_plugins.rename_accounts.rename_accounts': renameAccounts,
  'beancount_reds_plugins.zerosum.zerosum': zerosumPlugin,
};
