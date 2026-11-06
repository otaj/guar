// Explanations for ledger settings, and which option keys stay untouched while advanced is off.

import 'package:guar_book/guar_book.dart';

class SettingCopy {
  const SettingCopy({required this.summary, required this.detail, this.warning});

  final String summary;
  final String detail;
  final String? warning;
}

const Set<String> advancedOptionKeys = <String>{
  'documents',
  'render_commas',
  'long_string_maxlines',
  'plugin_processing_mode',
  'insert_pythonpath',
  'allow_pipe_separator',
  'allow_deprecated_none_for_tags_and_links',
  'account_previous_balances',
  'account_previous_earnings',
  'account_previous_conversions',
  'account_current_earnings',
  'account_current_conversions',
  'account_unrealized_gains',
  'account_rounding',
  'use_precise_interpolation',
  'infer_tolerance_from_cost',
  'tolerance_multiplier',
  'inferred_tolerance_multiplier',
  'inferred_tolerance_default',
  'default_tolerance',
  'display_precision',
};

const SettingCopy showAdvancedCopy = SettingCopy(
  summary: 'Shows options most ledgers leave at their defaults.',
  detail:
      'While this is off, those options are not shown. If the file already sets one, saving other settings leaves that line as it is.',
);

const SettingCopy advancedUiCopy = SettingCopy(
  summary: 'Shows the plugins screen.',
  detail:
      'When this is on, a Plugins tab is available so you can turn plugins on, set them up, and change their order. When it is off, plugin lines stay in the file and the tab is hidden.',
);

const SettingCopy writeDefaultsCopy = SettingCopy(
  summary: 'Write every visible option, including values that match the defaults.',
  detail:
      "Normally the file only stores options that differ from Beancount's defaults. Turn this on to write the full set Guar is using. Options hidden by Advanced settings are left as they are.",
);

const SettingCopy titleCopy = SettingCopy(
  summary: 'Name shown for this ledger.',
  detail: 'Beancount uses this as the report title. Guar shows it on the ledger screen. The default is Beancount.',
);

const SettingCopy operatingCopy = SettingCopy(
  summary: 'Currencies this ledger uses day to day.',
  detail:
      'Add one code per line, such as USD or EUR. Queries that need a default currency use the first one. Leave the list empty if you have not chosen any.',
);

const SettingCopy conversionCopy = SettingCopy(
  summary: 'Currency used when amounts are converted.',
  detail:
      'Queries that convert to a single currency use this. NOTHING means no conversion currency is set. Use a code such as USD when you want conversions.',
);

const SettingCopy bookingCopy = SettingCopy(
  summary: 'How a sale picks a lot when more than one could match.',
  detail:
      'STRICT requires the lot to be written out when several match. STRICT_WITH_SIZE also compares the lot size. NONE, FIFO, LIFO, HIFO, and AVERAGE pick a lot for you. The default is STRICT.',
);

const SettingCopy assetsCopy = SettingCopy(
  summary: 'Root name for accounts you own.',
  detail:
      'Every asset account starts with this name, then a colon. The default is Assets. Accounts already in the file are not renamed.',
);

const SettingCopy liabilitiesCopy = SettingCopy(
  summary: 'Root name for accounts you owe.',
  detail:
      'Every liability account starts with this name. The default is Liabilities. Accounts already in the file are not renamed.',
);

const SettingCopy equityCopy = SettingCopy(
  summary: 'Root name for equity accounts.',
  detail:
      'Opening balances and retained earnings sit under this name unless you set those accounts yourself. The default is Equity.',
);

const SettingCopy incomeCopy = SettingCopy(
  summary: 'Root name for income accounts.',
  detail:
      'Every income account starts with this name. The default is Income. Unrealized gains sit under it unless you set that account yourself.',
);

const SettingCopy expensesCopy = SettingCopy(
  summary: 'Root name for expense accounts.',
  detail: 'Every expense account starts with this name. The default is Expenses.',
);

const SettingCopy documentsCopy = SettingCopy(
  summary: 'Folders checked for files linked by document directives.',
  detail:
      'Each line is a root folder. Booking checks that a document path lives under one of them. Guar does not open the file.',
);

const SettingCopy renderCommasCopy = SettingCopy(
  summary: "Group digits with commas in Beancount's text output.",
  detail: "Beancount's own reports print 1,234.56 when this is on. Guar shows the digits that were recorded.",
  warning: 'No effect in Guar. Amounts are not grouped with commas.',
);

const SettingCopy maxLinesCopy = SettingCopy(
  summary: "How many lines a long string may use in Beancount's printer.",
  detail: 'This limits wrapping when Beancount prints the ledger. Guar saves strings as they were typed.',
  warning: 'No effect in Guar. Strings are not wrapped on save.',
);

const SettingCopy pluginModeCopy = SettingCopy(
  summary: 'Whether checks run before or after plugins.',
  detail:
      'DEFAULT runs document checks, padding, and balance checks around the plugins. RAW hands the plugins the entries before those steps. Use RAW only when a plugin expects it.',
);

const SettingCopy pythonPathCopy = SettingCopy(
  summary: "Add the ledger's folder to Python's import path.",
  detail:
      'Beancount does this so a Python plugin can import modules that sit next to the file. Guar does not run Python.',
  warning: 'No effect in Guar. Python plugins are not run.',
);

const SettingCopy pipeCopy = SettingCopy(
  summary: 'Allow a vertical bar between the payee and the narration.',
  detail:
      'Older files write the payee, a |, then the narration. Guar accepts that only when this is on. Beancount plans to remove the option.',
);

const SettingCopy deprecatedNoneCopy = SettingCopy(
  summary: 'Allow the word NONE where a tag or link was left out.',
  detail: "Older Beancount accepted NONE in that position. Guar's parser does not, whether this is on or off.",
  warning: 'No effect in Guar. NONE is not accepted as a tag or link.',
);

const SettingCopy previousBalancesCopy = SettingCopy(
  summary: 'Account that receives opening balances.',
  detail:
      'Queries that open the books on a date move the balance so far into this account. The default is Equity:Opening-Balances, and it follows the equity root when you have not set it.',
);

const SettingCopy previousEarningsCopy = SettingCopy(
  summary: 'Account for income and expenses from before the open date.',
  detail:
      'Queries that open or clear the books transfer prior income and expenses here. The default is Equity:Earnings:Previous.',
);

const SettingCopy previousConversionsCopy = SettingCopy(
  summary: 'Account for conversions from before the open date.',
  detail:
      'Queries that open the books park earlier currency conversions here. The default is Equity:Conversions:Previous.',
);

const SettingCopy currentEarningsCopy = SettingCopy(
  summary: 'Account for income and expenses when the books are closed.',
  detail:
      'Queries that close or clear the books transfer income and expenses here. The default is Equity:Earnings:Current.',
);

const SettingCopy currentConversionsCopy = SettingCopy(
  summary: 'Account for conversions when the books are closed.',
  detail: 'Queries that close the books park currency conversions here. The default is Equity:Conversions:Current.',
);

const SettingCopy unrealizedCopy = SettingCopy(
  summary: 'Account for unrealized gains.',
  detail:
      'Plugins that book unrealized gains use this income account. The default is Income:Earnings:Unrealized, and it follows the income root when you have not set it.',
);

const SettingCopy roundingCopy = SettingCopy(
  summary: 'Account that absorbs leftover cents after interpolation.',
  detail:
      "When a transaction's postings do not add up by a fraction, the remainder is booked here. Leave this empty to skip that posting.",
);

const SettingCopy preciseCopy = SettingCopy(
  summary: 'Interpolate missing amounts from the smallest tolerance.',
  detail:
      'When a posting amount is left blank, Guar fills it in. With this on, that fill uses the tighter tolerance. The default is off.',
);

const SettingCopy inferCostCopy = SettingCopy(
  summary: 'Guess balance tolerance from the cost, not only the units.',
  detail:
      "A balance check normally looks at the digits of the units. Turn this on to also consider the cost's digits. The default is off.",
);

const SettingCopy toleranceCopy = SettingCopy(
  summary: 'Newer name for the tolerance scale.',
  detail:
      'Beancount renamed the tolerance scale to tolerance_multiplier. Guar stores the value, and balance checks still read Inferred tolerance multiplier.',
  warning: 'No effect in Guar. Balance checks use Inferred tolerance multiplier.',
);

const SettingCopy inferredMultiplierCopy = SettingCopy(
  summary: 'Scale for tolerance guessed from the number of digits.',
  detail:
      'A number with two decimal places allows about 0.01 times this scale. Guar uses it for balance checks and for filling in blank posting amounts. The default is 0.5.',
);

const SettingCopy inferredDefaultsCopy = SettingCopy(
  summary: 'Fixed tolerance for a currency, instead of guessing from the digits.',
  detail:
      'The key is * for every currency, or a code such as USD. The number is the tolerance, such as 0.01. These override the guessed tolerance for that currency.',
);

const SettingCopy precisionCopy = SettingCopy(
  summary: 'Digits Beancount prints for a currency.',
  detail:
      'The key is *, a currency such as USD, or a pair such as USD/EUR. The number is how many decimal places to print. Guar shows the digits that were recorded.',
  warning: 'No effect in Guar. Amounts keep the digits that were recorded.',
);

SettingCopy hideCopy(GuarHide item) => switch (item) {
  GuarHide.generated => const SettingCopy(
    summary: 'Leaves entries from plugins and padding off the list.',
    detail:
        'Hides entries that plugins or balance padding added. What you wrote stays visible, and nothing is removed from the file.',
  ),
  GuarHide.transaction => const SettingCopy(
    summary: 'Leaves transactions off the list.',
    detail: 'Hides transactions on the ledger screen. They stay in the file.',
  ),
  GuarHide.price => const SettingCopy(
    summary: 'Leaves prices off the list.',
    detail: 'Hides price directives on the ledger screen. They stay in the file.',
  ),
  GuarHide.balance => const SettingCopy(
    summary: 'Leaves balance assertions off the list.',
    detail: 'Hides balance assertions on the ledger screen. They stay in the file.',
  ),
  GuarHide.open => const SettingCopy(
    summary: 'Leaves account opens off the list.',
    detail: 'Hides open directives on the ledger screen. They stay in the file.',
  ),
  GuarHide.close => const SettingCopy(
    summary: 'Leaves account closes off the list.',
    detail: 'Hides close directives on the ledger screen. They stay in the file.',
  ),
  GuarHide.commodity => const SettingCopy(
    summary: 'Leaves commodities off the list.',
    detail: 'Hides commodity directives on the ledger screen. They stay in the file.',
  ),
  GuarHide.pad => const SettingCopy(
    summary: 'Leaves pads off the list.',
    detail: 'Hides pad directives on the ledger screen. They stay in the file.',
  ),
  GuarHide.document => const SettingCopy(
    summary: 'Leaves documents off the list.',
    detail: 'Hides document directives on the ledger screen. They stay in the file.',
  ),
  GuarHide.note => const SettingCopy(
    summary: 'Leaves notes off the list.',
    detail: 'Hides notes on the ledger screen. They stay in the file.',
  ),
  GuarHide.event => const SettingCopy(
    summary: 'Leaves events off the list.',
    detail: 'Hides events on the ledger screen. They stay in the file.',
  ),
  GuarHide.query => const SettingCopy(
    summary: 'Leaves queries off the list.',
    detail: 'Hides query directives on the ledger screen. They stay in the file.',
  ),
  GuarHide.custom => const SettingCopy(
    summary: 'Leaves custom directives off the list.',
    detail: 'Hides custom directives on the ledger screen. They stay in the file.',
  ),
  GuarHide.budget => const SettingCopy(
    summary: 'Leaves budgets off the list.',
    detail: 'Hides budget directives on the ledger screen. They stay in the file.',
  ),
  GuarHide.budgetOff => const SettingCopy(
    summary: 'Leaves budget-off directives off the list.',
    detail: 'Hides budget-off directives on the ledger screen. They stay in the file.',
  ),
};
