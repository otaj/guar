// Reds plugins in registry order, with the text the app shows.

import 'package:guar_plugins/src/close_tree.dart';
import 'package:guar_plugins/src/plugin_codecs.dart';
import 'package:guar_plugins/src/plugin_info.dart';
import 'package:guar_plugins/src/reds/box_accrual.dart';
import 'package:guar_plugins/src/reds/daf_mirror.dart';
import 'package:guar_plugins/src/reds/effective_date.dart';
import 'package:guar_plugins/src/reds/gain_loss.dart';
import 'package:guar_plugins/src/reds/long_short.dart';
import 'package:guar_plugins/src/reds/opengroup.dart';
import 'package:guar_plugins/src/reds/rename_accounts.dart';
import 'package:guar_plugins/src/reds/zerosum.dart';

final List<PluginDeclaration> redsCatalog = <PluginDeclaration>[
  const PluginDeclaration(
    name: 'beancount_reds_plugins.autoclose_tree.autoclose_tree',
    description:
        'When an account is closed, also closes every descendant that is still open. '
        'This is the reds name for the same behavior as beancount.plugins.close_tree.',
    apply: closeTree,
  ),
  const PluginDeclaration(
    name: 'beancount_reds_plugins.box_accrual.box_accrual',
    description:
        'Spreads a box-spread capital loss across the calendar years of the loan, '
        'using synthetic_loan_expiry metadata.',
    apply: boxAccrual,
  ),
  const PluginDeclaration(
    name: 'beancount_reds_plugins.capital_gains_classifier.gain_loss',
    description:
        'Rewrites capital-gains accounts into a gains account or a losses account. '
        'A negative amount uses the third column, and a positive amount uses the fourth.',
    apply: gainLoss,
    setup: gainLossSetup,
  ),
  const PluginDeclaration(
    name: 'beancount_reds_plugins.capital_gains_classifier.long_short',
    description:
        'Splits a capital-gains posting into short-term and long-term accounts by the IRS holding period. '
        'Only the first rule is applied. With no rule, the plugin reports an error and does nothing.',
    apply: longShort,
    setup: longShortSetup,
  ),
  const PluginDeclaration(
    name: 'beancount_reds_plugins.daf.daf_mirror',
    description:
        'Mirrors transactions under an account prefix onto liability accounts with the same path. '
        'The mirror payee starts with the payee prefix.',
    apply: dafMirror,
    setup: dafSetup,
  ),
  const PluginDeclaration(
    name: 'beancount_reds_plugins.effective_date.effective_date',
    description:
        'Moves a posting that has effective_date metadata onto a holding account until that date, then back. '
        'Each row is an account prefix and the holding accounts for an earlier or later effective date.',
    apply: effectiveDate,
    setup: effectiveDateSetup,
  ),
  const PluginDeclaration(
    name: 'beancount_reds_plugins.opengroup.opengroup',
    description:
        'When an open or close has opengroup_ or closegroup_ metadata, inserts the matching accounts. '
        'With no rules here, the built-in investment rules are used. Rules you add replace those defaults.',
    apply: opengroup,
    setup: opengroupSetup,
  ),
  const PluginDeclaration(
    name: 'beancount_reds_plugins.rename_accounts.rename_accounts',
    description:
        'Renames accounts by regular expression, in row order. Later rows see the names earlier rows produced.',
    apply: renameAccounts,
    setup: renameAccountsSetup,
  ),
  PluginDeclaration(
    name: 'beancount_reds_plugins.zerosum.zerosum',
    description:
        'Pairs postings in the listed accounts that sum to zero, within a tolerance and a number of days, '
        'and moves them to the target account.',
    apply: zerosumPlugin,
    setup: zerosumSetup,
  ),
];
