// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class GuarLocalizationsEn extends GuarLocalizations {
  GuarLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabLedger => 'Ledger';

  @override
  String get tabBalances => 'Balances';

  @override
  String get tabPrices => 'Prices';

  @override
  String get tabPlugins => 'Plugins';

  @override
  String get tabSettings => 'Settings';

  @override
  String get newTransaction => 'New transaction';

  @override
  String get newAccount => 'New account';

  @override
  String get openLedger => 'Open a ledger';

  @override
  String get pickLedgerHint => 'Choose the root ledger file. That choice stays in the app.';

  @override
  String get createLedger => 'Create a new ledger';

  @override
  String get optionsTitle => 'Options';

  @override
  String get noLedgerSelected => 'No ledger is selected.';

  @override
  String get noLedgerSelectedSettings => 'No ledger is selected. Choose one in Settings.';

  @override
  String get couldNotSave => 'Could not save that option.';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageSummary => 'The language Guar uses, whatever the phone is set to.';

  @override
  String get languageDetail =>
      'System default follows the phone language. When that language is not one of the languages Guar is translated to, Guar uses English.';

  @override
  String get sectionApp => 'App';

  @override
  String get appSummary => 'How Guar presents this ledger, and which options it writes.';

  @override
  String get sectionLedgerScreen => 'Ledger screen';

  @override
  String get ledgerScreenSummary => 'Choose types to leave off the ledger screen. The entries stay in the file.';

  @override
  String get sectionLedger => 'Ledger';

  @override
  String get ledgerSummary => 'The name of the books, the currencies, and how lots are booked.';

  @override
  String get sectionAccountNames => 'Account names';

  @override
  String get accountNamesSummary => 'Every account starts with one of these five roots.';

  @override
  String get sectionDocuments => 'Documents';

  @override
  String get documentsSummary => 'Where document directives look for files.';

  @override
  String get sectionBookingDetails => 'Booking details';

  @override
  String get bookingDetailsSummary => 'Tolerances, interpolation, and where leftover cents go.';

  @override
  String get sectionSystemAccounts => 'System accounts';

  @override
  String get systemAccountsSummary => 'Accounts used when queries open, close, or clear the books.';

  @override
  String get sectionPlugins => 'Plugins';

  @override
  String get pluginsSummary => 'When plugins run relative to the other checks.';

  @override
  String get sectionCompatibility => 'Compatibility';

  @override
  String get compatibilitySummary => 'Older syntax, and options kept for other Beancount tools.';

  @override
  String get labelAdvancedSettings => 'Advanced settings';

  @override
  String get labelAdvancedUi => 'Advanced UI';

  @override
  String get labelWriteDefaultOptions => 'Write default options';

  @override
  String get labelAllowUnopenedAccounts => 'Allow unopened accounts';

  @override
  String get labelIncludeInferredPrices => 'Include inferred prices';

  @override
  String get labelPreciseInterpolation => 'Precise interpolation';

  @override
  String get labelInferToleranceFromCost => 'Infer tolerance from cost';

  @override
  String get labelAllowPipeSeparator => 'Allow pipe separator';

  @override
  String get labelAllowDeprecatedNone => 'Allow deprecated none for tags and links';

  @override
  String get labelInsertPythonPath => 'Insert Python path';

  @override
  String get labelRenderCommas => 'Render commas';

  @override
  String get labelTitle => 'Title';

  @override
  String get labelOperatingCurrencies => 'Operating currencies';

  @override
  String get labelConversionCurrency => 'Conversion currency';

  @override
  String get labelBookingMethod => 'Booking method';

  @override
  String get labelAssets => 'Assets';

  @override
  String get labelLiabilities => 'Liabilities';

  @override
  String get labelEquity => 'Equity';

  @override
  String get labelIncome => 'Income';

  @override
  String get labelExpenses => 'Expenses';

  @override
  String get labelDocumentsField => 'Documents';

  @override
  String get labelToleranceMultiplier => 'Tolerance multiplier';

  @override
  String get labelInferredToleranceMultiplier => 'Inferred tolerance multiplier';

  @override
  String get labelInferredToleranceDefaults => 'Inferred tolerance defaults';

  @override
  String get labelRoundingAccount => 'Rounding account';

  @override
  String get labelPreviousBalances => 'Previous balances';

  @override
  String get labelPreviousEarnings => 'Previous earnings';

  @override
  String get labelPreviousConversions => 'Previous conversions';

  @override
  String get labelCurrentEarnings => 'Current earnings';

  @override
  String get labelCurrentConversions => 'Current conversions';

  @override
  String get labelUnrealizedGains => 'Unrealized gains';

  @override
  String get labelPluginMode => 'Plugin processing mode';

  @override
  String get labelLongStringMaxLines => 'Long string max lines';

  @override
  String get labelDisplayPrecision => 'Display precision';

  @override
  String addLabel(String label) {
    return 'Add $label';
  }

  @override
  String get keyLabel => 'Key';

  @override
  String get numberLabel => 'Number';

  @override
  String get valueLabel => 'Value';

  @override
  String get closeLabel => 'Close';

  @override
  String get hideGenerated => 'Generated';

  @override
  String get hideTransaction => 'Transaction';

  @override
  String get hidePrice => 'Price';

  @override
  String get hideBalance => 'Balance';

  @override
  String get hideOpen => 'Open';

  @override
  String get hideClose => 'Close';

  @override
  String get hideCommodity => 'Commodity';

  @override
  String get hidePad => 'Pad';

  @override
  String get hideDocument => 'Document';

  @override
  String get hideNote => 'Note';

  @override
  String get hideEvent => 'Event';

  @override
  String get hideQuery => 'Query';

  @override
  String get hideCustom => 'Custom';

  @override
  String get hideBudget => 'Budget';

  @override
  String get hideBudgetOff => 'Budget off';

  @override
  String get copyShowAdvancedSummary => 'Shows options most ledgers leave at their defaults.';

  @override
  String get copyShowAdvancedDetail =>
      'While this is off, those options are not shown. If the file already sets one, saving other settings leaves that line as it is.';

  @override
  String get copyAdvancedUiSummary => 'Shows the plugins screen.';

  @override
  String get copyAdvancedUiDetail =>
      'When this is on, a Plugins tab is available so you can turn plugins on, set them up, and change their order. When it is off, plugin lines stay in the file and the tab is hidden.';

  @override
  String get copyWriteDefaultsSummary => 'Write every visible option, including values that match the defaults.';

  @override
  String get copyWriteDefaultsDetail =>
      'Normally the file only stores options that differ from Beancount\'s defaults. Turn this on to write the full set Guar is using. Options hidden by Advanced settings are left as they are.';

  @override
  String get copyAllowUnopenedSummary => 'Type any account in the transaction editor.';

  @override
  String get copyAllowUnopenedDetail =>
      'When this is on, the account pickers become plain text fields, so a posting can name an account no open directive shows, for example one a plugin such as autoopen opens. Accounts that nothing opens are still rejected when saving.';

  @override
  String get copyIncludeInferredSummary => 'List prices inferred from transactions.';

  @override
  String get copyIncludeInferredDetail =>
      'The price database always shows explicit price directives. Turn this on to also list rates read from posting prices and costs in transactions, marked as inferred.';

  @override
  String get copyTitleSummary => 'Name shown for this ledger.';

  @override
  String get copyTitleDetail =>
      'Beancount uses this as the report title. Guar shows it on the ledger screen. The default is Beancount.';

  @override
  String get copyOperatingSummary => 'Currencies this ledger uses day to day.';

  @override
  String get copyOperatingDetail =>
      'Add one code per line, such as USD or EUR. Queries that need a default currency use the first one. Leave the list empty if you have not chosen any.';

  @override
  String get copyConversionSummary => 'Currency used when amounts are converted.';

  @override
  String get copyConversionDetail =>
      'Queries that convert to a single currency use this. NOTHING means no conversion currency is set. Use a code such as USD when you want conversions.';

  @override
  String get copyBookingSummary => 'How a sale picks a lot when more than one could match.';

  @override
  String get copyBookingDetail =>
      'STRICT requires the lot to be written out when several match. STRICT_WITH_SIZE also compares the lot size. NONE, FIFO, LIFO, HIFO, and AVERAGE pick a lot for you. The default is STRICT.';

  @override
  String get copyAssetsSummary => 'Root name for accounts you own.';

  @override
  String get copyAssetsDetail =>
      'Every asset account starts with this name, then a colon. The default is Assets. Accounts already in the file are not renamed.';

  @override
  String get copyLiabilitiesSummary => 'Root name for accounts you owe.';

  @override
  String get copyLiabilitiesDetail =>
      'Every liability account starts with this name. The default is Liabilities. Accounts already in the file are not renamed.';

  @override
  String get copyEquitySummary => 'Root name for equity accounts.';

  @override
  String get copyEquityDetail =>
      'Opening balances and retained earnings sit under this name unless you set those accounts yourself. The default is Equity.';

  @override
  String get copyIncomeSummary => 'Root name for income accounts.';

  @override
  String get copyIncomeDetail =>
      'Every income account starts with this name. The default is Income. Unrealized gains sit under it unless you set that account yourself.';

  @override
  String get copyExpensesSummary => 'Root name for expense accounts.';

  @override
  String get copyExpensesDetail => 'Every expense account starts with this name. The default is Expenses.';

  @override
  String get copyDocumentsSummary => 'Folders checked for files linked by document directives.';

  @override
  String get copyDocumentsDetail =>
      'Each line is a root folder. Booking checks that a document path lives under one of them. Guar does not open the file.';

  @override
  String get copyRenderCommasSummary => 'Group digits with commas in Beancount\'s text output.';

  @override
  String get copyRenderCommasDetail =>
      'Beancount\'s own reports print 1,234.56 when this is on. Guar shows the digits that were recorded.';

  @override
  String get copyRenderCommasWarning => 'No effect in Guar. Amounts are not grouped with commas.';

  @override
  String get copyMaxLinesSummary => 'How many lines a long string may use in Beancount\'s printer.';

  @override
  String get copyMaxLinesDetail =>
      'This limits wrapping when Beancount prints the ledger. Guar saves strings as they were typed.';

  @override
  String get copyMaxLinesWarning => 'No effect in Guar. Strings are not wrapped on save.';

  @override
  String get copyPluginModeSummary => 'Whether checks run before or after plugins.';

  @override
  String get copyPluginModeDetail =>
      'DEFAULT runs document checks, padding, and balance checks around the plugins. RAW hands the plugins the entries before those steps. Use RAW only when a plugin expects it.';

  @override
  String get copyPythonPathSummary => 'Add the ledger\'s folder to Python\'s import path.';

  @override
  String get copyPythonPathDetail =>
      'Beancount does this so a Python plugin can import modules that sit next to the file. Guar does not run Python.';

  @override
  String get copyPythonPathWarning => 'No effect in Guar. Python plugins are not run.';

  @override
  String get copyPipeSummary => 'Allow a vertical bar between the payee and the narration.';

  @override
  String get copyPipeDetail =>
      'Older files write the payee, a |, then the narration. Guar accepts that only when this is on. Beancount plans to remove the option.';

  @override
  String get copyDeprecatedNoneSummary => 'Allow the word NONE where a tag or link was left out.';

  @override
  String get copyDeprecatedNoneDetail =>
      'Older Beancount accepted NONE in that position. Guar\'s parser does not, whether this is on or off.';

  @override
  String get copyDeprecatedNoneWarning => 'No effect in Guar. NONE is not accepted as a tag or link.';

  @override
  String get copyPreviousBalancesSummary => 'Account that receives opening balances.';

  @override
  String get copyPreviousBalancesDetail =>
      'Queries that open the books on a date move the balance so far into this account. The default is Equity:Opening-Balances, and it follows the equity root when you have not set it.';

  @override
  String get copyPreviousEarningsSummary => 'Account for income and expenses from before the open date.';

  @override
  String get copyPreviousEarningsDetail =>
      'Queries that open or clear the books transfer prior income and expenses here. The default is Equity:Earnings:Previous.';

  @override
  String get copyPreviousConversionsSummary => 'Account for conversions from before the open date.';

  @override
  String get copyPreviousConversionsDetail =>
      'Queries that open the books park earlier currency conversions here. The default is Equity:Conversions:Previous.';

  @override
  String get copyCurrentEarningsSummary => 'Account for income and expenses when the books are closed.';

  @override
  String get copyCurrentEarningsDetail =>
      'Queries that close or clear the books transfer income and expenses here. The default is Equity:Earnings:Current.';

  @override
  String get copyCurrentConversionsSummary => 'Account for conversions when the books are closed.';

  @override
  String get copyCurrentConversionsDetail =>
      'Queries that close the books park currency conversions here. The default is Equity:Conversions:Current.';

  @override
  String get copyUnrealizedSummary => 'Account for unrealized gains.';

  @override
  String get copyUnrealizedDetail =>
      'Plugins that book unrealized gains use this income account. The default is Income:Earnings:Unrealized, and it follows the income root when you have not set it.';

  @override
  String get copyRoundingSummary => 'Account that absorbs leftover cents after interpolation.';

  @override
  String get copyRoundingDetail =>
      'When a transaction\'s postings do not add up by a fraction, the remainder is booked here. Leave this empty to skip that posting.';

  @override
  String get copyPreciseSummary => 'Interpolate missing amounts from the smallest tolerance.';

  @override
  String get copyPreciseDetail =>
      'When a posting amount is left blank, Guar fills it in. With this on, that fill uses the tighter tolerance. The default is off.';

  @override
  String get copyInferCostSummary => 'Guess balance tolerance from the cost, not only the units.';

  @override
  String get copyInferCostDetail =>
      'A balance check normally looks at the digits of the units. Turn this on to also consider the cost\'s digits. The default is off.';

  @override
  String get copyToleranceSummary => 'Newer name for the tolerance scale.';

  @override
  String get copyToleranceDetail =>
      'Beancount renamed the tolerance scale to tolerance_multiplier. Guar stores the value, and balance checks still read Inferred tolerance multiplier.';

  @override
  String get copyToleranceWarning => 'No effect in Guar. Balance checks use Inferred tolerance multiplier.';

  @override
  String get copyInferredMultiplierSummary => 'Scale for tolerance guessed from the number of digits.';

  @override
  String get copyInferredMultiplierDetail =>
      'A number with two decimal places allows about 0.01 times this scale. Guar uses it for balance checks and for filling in blank posting amounts. The default is 0.5.';

  @override
  String get copyInferredDefaultsSummary => 'Fixed tolerance for a currency, instead of guessing from the digits.';

  @override
  String get copyInferredDefaultsDetail =>
      'The key is * for every currency, or a code such as USD. The number is the tolerance, such as 0.01. These override the guessed tolerance for that currency.';

  @override
  String get copyPrecisionSummary => 'Digits Beancount prints for a currency.';

  @override
  String get copyPrecisionDetail =>
      'The key is *, a currency such as USD, or a pair such as USD/EUR. The number is how many decimal places to print. Guar shows the digits that were recorded.';

  @override
  String get copyPrecisionWarning => 'No effect in Guar. Amounts keep the digits that were recorded.';

  @override
  String get copyHideGeneratedSummary => 'Leaves entries from plugins and padding off the list.';

  @override
  String get copyHideGeneratedDetail =>
      'Hides entries that plugins or balance padding added. What you wrote stays visible, and nothing is removed from the file.';

  @override
  String get copyHideTransactionSummary => 'Leaves transactions off the list.';

  @override
  String get copyHideTransactionDetail => 'Hides transactions on the ledger screen. They stay in the file.';

  @override
  String get copyHidePriceSummary => 'Leaves prices off the list.';

  @override
  String get copyHidePriceDetail => 'Hides price directives on the ledger screen. They stay in the file.';

  @override
  String get copyHideBalanceSummary => 'Leaves balance assertions off the list.';

  @override
  String get copyHideBalanceDetail => 'Hides balance assertions on the ledger screen. They stay in the file.';

  @override
  String get copyHideOpenSummary => 'Leaves account opens off the list.';

  @override
  String get copyHideOpenDetail => 'Hides open directives on the ledger screen. They stay in the file.';

  @override
  String get copyHideCloseSummary => 'Leaves account closes off the list.';

  @override
  String get copyHideCloseDetail => 'Hides close directives on the ledger screen. They stay in the file.';

  @override
  String get copyHideCommoditySummary => 'Leaves commodities off the list.';

  @override
  String get copyHideCommodityDetail => 'Hides commodity directives on the ledger screen. They stay in the file.';

  @override
  String get copyHidePadSummary => 'Leaves pads off the list.';

  @override
  String get copyHidePadDetail => 'Hides pad directives on the ledger screen. They stay in the file.';

  @override
  String get copyHideDocumentSummary => 'Leaves documents off the list.';

  @override
  String get copyHideDocumentDetail => 'Hides document directives on the ledger screen. They stay in the file.';

  @override
  String get copyHideNoteSummary => 'Leaves notes off the list.';

  @override
  String get copyHideNoteDetail => 'Hides notes on the ledger screen. They stay in the file.';

  @override
  String get copyHideEventSummary => 'Leaves events off the list.';

  @override
  String get copyHideEventDetail => 'Hides events on the ledger screen. They stay in the file.';

  @override
  String get copyHideQuerySummary => 'Leaves queries off the list.';

  @override
  String get copyHideQueryDetail => 'Hides query directives on the ledger screen. They stay in the file.';

  @override
  String get copyHideCustomSummary => 'Leaves custom directives off the list.';

  @override
  String get copyHideCustomDetail => 'Hides custom directives on the ledger screen. They stay in the file.';

  @override
  String get copyHideBudgetSummary => 'Leaves budgets off the list.';

  @override
  String get copyHideBudgetDetail => 'Hides budget directives on the ledger screen. They stay in the file.';

  @override
  String get copyHideBudgetOffSummary => 'Leaves budget-off directives off the list.';

  @override
  String get copyHideBudgetOffDetail => 'Hides budget-off directives on the ledger screen. They stay in the file.';

  @override
  String get everyDirectiveHidden => 'Every directive is hidden.';

  @override
  String get noDirectives => 'This ledger has no directives.';

  @override
  String postingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count postings',
      one: '$count posting',
    );
    return '$_temp0';
  }

  @override
  String get noDescription => '(no description)';

  @override
  String warningsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings',
      one: '$count warning',
    );
    return '$_temp0';
  }

  @override
  String metaFrom(String account) {
    return 'from $account';
  }

  @override
  String get typeAssets => 'Assets';

  @override
  String get typeExpenses => 'Expenses';

  @override
  String get typeIncome => 'Income';

  @override
  String get typeLiabilities => 'Liabilities';

  @override
  String get typeEquity => 'Equity';

  @override
  String closedDate(String date) {
    return 'Closed $date';
  }

  @override
  String get noActivity => 'No activity';

  @override
  String moreCount(int count) {
    return '+$count more';
  }

  @override
  String get pluginsHint => 'Plugins run from top to bottom. Drag a plugin to change that order.';

  @override
  String get noPluginsOn => 'None of the plugins are turned on.';

  @override
  String get availableTitle => 'Available';

  @override
  String get viewByDate => 'By date';

  @override
  String get viewByPair => 'By pair';

  @override
  String get priceInferred => 'inferred';

  @override
  String get noPrices => 'This ledger has no prices.';

  @override
  String pricesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prices',
      one: '$count price',
    );
    return '$_temp0';
  }

  @override
  String get timeframeAll => 'All';

  @override
  String get dragTooltip => 'Drag to change the order';

  @override
  String get showDescription => 'Show description';

  @override
  String get hideDescription => 'Hide description';

  @override
  String get unknownPlugin =>
      'This plugin is not one of the built-in plugins. Its configuration is kept as written in the ledger.';

  @override
  String get configLabel => 'Configuration';

  @override
  String get addRule => 'Add rule';

  @override
  String get addInsert => 'Add insert';

  @override
  String get removeRule => 'Remove rule';

  @override
  String get ruleName => 'Rule name';

  @override
  String get accountPattern => 'Account pattern';

  @override
  String get accountTemplate => 'Account template';

  @override
  String get currenciesTemplate => 'Currencies template';

  @override
  String get enterDecimal => 'Enter a decimal';

  @override
  String get enterWholeNumber => 'Enter a whole number';

  @override
  String get openAccount => 'Open account';

  @override
  String get editTransaction => 'Edit transaction';

  @override
  String get editTransactionButton => 'Save transaction';

  @override
  String get editNeedsAdvanced =>
      'This transaction uses advanced features. Turn on Advanced UI in Settings to edit it.';

  @override
  String get cannotEditGenerated => 'Generated entries cannot be edited.';

  @override
  String get labelDate => 'Date';

  @override
  String get labelAccount => 'Account';

  @override
  String get labelCurrenciesComma => 'Currencies (comma separated)';

  @override
  String get bookingDefault => 'Default';

  @override
  String get metadata => 'Metadata';

  @override
  String get labelDescription => 'Description (optional)';

  @override
  String get labelPayee => 'Payee (optional)';

  @override
  String get statusTitle => 'Status';

  @override
  String get postingsTitle => 'Postings';

  @override
  String get addPosting => 'Add posting';

  @override
  String get labelFile => 'File';

  @override
  String get addTransactionButton => 'Add transaction';

  @override
  String get autoBalanceHint => 'Leave one posting amount empty for auto-balancing.';

  @override
  String get needTwoAccounts =>
      'You need at least two open accounts to create a transaction. Open them with the plus button first.';

  @override
  String get labelAmount => 'Amount';

  @override
  String get autoHint => 'Auto';

  @override
  String get fromAccount => 'From account';

  @override
  String get toAccount => 'To account';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get newTag => 'New tag';

  @override
  String get linksTitle => 'Links';

  @override
  String get newLink => 'New link';

  @override
  String get labelName => 'Name';

  @override
  String get nameHint => 'e.g. trip-2024';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get customFlagEllipsis => 'Custom flag...';

  @override
  String get customFlagTitle => 'Custom Flag';

  @override
  String get singleCharacter => 'Single character';

  @override
  String get set => 'Set';

  @override
  String notOpened(String account) {
    return '$account is not opened.';
  }

  @override
  String get notOpenedHint => 'Open the account, or turn a plugin on that opens it.';

  @override
  String get turnPluginOn => 'Turn a plugin on';

  @override
  String postingIndex(int number) {
    return 'Posting $number';
  }

  @override
  String get noFlag => 'No flag';

  @override
  String get noPrice => 'No price';

  @override
  String get noCost => 'No cost';

  @override
  String get totalPrice => 'Total price';

  @override
  String get pricePerUnit => 'Price per unit';

  @override
  String get totalCost => 'Total cost';

  @override
  String get costPerUnit => 'Cost per unit';

  @override
  String get labelCurrency => 'Currency';

  @override
  String get none => 'None';

  @override
  String get flagCompleted => '* (Completed)';

  @override
  String get flagIncomplete => '! (Incomplete)';

  @override
  String get transactionMetaTitle => 'Transaction metadata';

  @override
  String get postingMetaTitle => 'Posting metadata';

  @override
  String get keyHint => 'key';

  @override
  String get valueHint => 'value';

  @override
  String get couldNotWriteIncluded => 'Could not write the included ledger file.';

  @override
  String get couldNotSaveTransaction => 'Could not save the transaction.';

  @override
  String get couldNotUseFile => 'Could not use that file.';

  @override
  String get couldNotReadTarget => 'Could not read the target file.';

  @override
  String get errInvalidAccountName => 'not a valid account name';

  @override
  String get errInvalidCurrencyCode => 'not a valid currency code';

  @override
  String get errWholeNumberZeroOrGreater => 'Enter a whole number zero or greater';

  @override
  String get errEnterNumber => 'Enter a number';

  @override
  String get errQuotesNotAllowed => 'Quotes cannot be stored in an option value';
}
