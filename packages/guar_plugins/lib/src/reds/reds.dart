// Default map of beancount_reds_plugins module names to Dart BookPlugin implementations.

import 'package:guar_plugins/src/close_tree.dart';
import 'package:guar_plugins/src/plugin.dart';
import 'package:guar_plugins/src/reds/box_accrual.dart';
import 'package:guar_plugins/src/reds/daf_mirror.dart';
import 'package:guar_plugins/src/reds/effective_date.dart';
import 'package:guar_plugins/src/reds/gain_loss.dart';
import 'package:guar_plugins/src/reds/long_short.dart';
import 'package:guar_plugins/src/reds/opengroup.dart';
import 'package:guar_plugins/src/reds/rename_accounts.dart';
import 'package:guar_plugins/src/reds/zerosum.dart';

final Map<String, BookPlugin> redsPlugins = <String, BookPlugin>{
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
