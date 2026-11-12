import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of GuarLocalizations
/// returned by `GuarLocalizations.of(context)`.
///
/// Applications need to include `GuarLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: GuarLocalizations.localizationsDelegates,
///   supportedLocales: GuarLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the GuarLocalizations.supportedLocales
/// property.
abstract class GuarLocalizations {
  GuarLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static GuarLocalizations of(BuildContext context) {
    return Localizations.of<GuarLocalizations>(context, GuarLocalizations)!;
  }

  static const LocalizationsDelegate<GuarLocalizations> delegate = _GuarLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @tabLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get tabLedger;

  /// No description provided for @tabBalances.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get tabBalances;

  /// No description provided for @tabPrices.
  ///
  /// In en, this message translates to:
  /// **'Prices'**
  String get tabPrices;

  /// No description provided for @tabPlugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get tabPlugins;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @newTransaction.
  ///
  /// In en, this message translates to:
  /// **'New transaction'**
  String get newTransaction;

  /// No description provided for @newAccount.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get newAccount;

  /// No description provided for @openLedger.
  ///
  /// In en, this message translates to:
  /// **'Open a ledger'**
  String get openLedger;

  /// No description provided for @pickLedgerHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the root ledger file. That choice stays in the app.'**
  String get pickLedgerHint;

  /// No description provided for @createLedger.
  ///
  /// In en, this message translates to:
  /// **'Create a new ledger'**
  String get createLedger;

  /// No description provided for @optionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get optionsTitle;

  /// No description provided for @noLedgerSelected.
  ///
  /// In en, this message translates to:
  /// **'No ledger is selected.'**
  String get noLedgerSelected;

  /// No description provided for @noLedgerSelectedSettings.
  ///
  /// In en, this message translates to:
  /// **'No ledger is selected. Choose one in Settings.'**
  String get noLedgerSelectedSettings;

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save that option.'**
  String get couldNotSave;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageSummary.
  ///
  /// In en, this message translates to:
  /// **'The language Guar uses, whatever the phone is set to.'**
  String get languageSummary;

  /// No description provided for @languageDetail.
  ///
  /// In en, this message translates to:
  /// **'System default follows the phone language. When that language is not one of the languages Guar is translated to, Guar uses English.'**
  String get languageDetail;

  /// No description provided for @sectionApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get sectionApp;

  /// No description provided for @appSummary.
  ///
  /// In en, this message translates to:
  /// **'How Guar presents this ledger, and which options it writes.'**
  String get appSummary;

  /// No description provided for @sectionLedgerScreen.
  ///
  /// In en, this message translates to:
  /// **'Ledger screen'**
  String get sectionLedgerScreen;

  /// No description provided for @ledgerScreenSummary.
  ///
  /// In en, this message translates to:
  /// **'Choose types to leave off the ledger screen. The entries stay in the file.'**
  String get ledgerScreenSummary;

  /// No description provided for @sectionLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get sectionLedger;

  /// No description provided for @ledgerSummary.
  ///
  /// In en, this message translates to:
  /// **'The name of the books, the currencies, and how lots are booked.'**
  String get ledgerSummary;

  /// No description provided for @sectionAccountNames.
  ///
  /// In en, this message translates to:
  /// **'Account names'**
  String get sectionAccountNames;

  /// No description provided for @accountNamesSummary.
  ///
  /// In en, this message translates to:
  /// **'Every account starts with one of these five roots.'**
  String get accountNamesSummary;

  /// No description provided for @sectionDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get sectionDocuments;

  /// No description provided for @documentsSummary.
  ///
  /// In en, this message translates to:
  /// **'Where document directives look for files.'**
  String get documentsSummary;

  /// No description provided for @sectionBookingDetails.
  ///
  /// In en, this message translates to:
  /// **'Booking details'**
  String get sectionBookingDetails;

  /// No description provided for @bookingDetailsSummary.
  ///
  /// In en, this message translates to:
  /// **'Tolerances, interpolation, and where leftover cents go.'**
  String get bookingDetailsSummary;

  /// No description provided for @sectionSystemAccounts.
  ///
  /// In en, this message translates to:
  /// **'System accounts'**
  String get sectionSystemAccounts;

  /// No description provided for @systemAccountsSummary.
  ///
  /// In en, this message translates to:
  /// **'Accounts used when queries open, close, or clear the books.'**
  String get systemAccountsSummary;

  /// No description provided for @sectionPlugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get sectionPlugins;

  /// No description provided for @pluginsSummary.
  ///
  /// In en, this message translates to:
  /// **'When plugins run relative to the other checks.'**
  String get pluginsSummary;

  /// No description provided for @sectionCompatibility.
  ///
  /// In en, this message translates to:
  /// **'Compatibility'**
  String get sectionCompatibility;

  /// No description provided for @compatibilitySummary.
  ///
  /// In en, this message translates to:
  /// **'Older syntax, and options kept for other Beancount tools.'**
  String get compatibilitySummary;

  /// No description provided for @labelAdvancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get labelAdvancedSettings;

  /// No description provided for @labelAdvancedUi.
  ///
  /// In en, this message translates to:
  /// **'Advanced UI'**
  String get labelAdvancedUi;

  /// No description provided for @labelWriteDefaultOptions.
  ///
  /// In en, this message translates to:
  /// **'Write default options'**
  String get labelWriteDefaultOptions;

  /// No description provided for @labelAllowUnopenedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Allow unopened accounts'**
  String get labelAllowUnopenedAccounts;

  /// No description provided for @labelIncludeInferredPrices.
  ///
  /// In en, this message translates to:
  /// **'Include inferred prices'**
  String get labelIncludeInferredPrices;

  /// No description provided for @labelPreciseInterpolation.
  ///
  /// In en, this message translates to:
  /// **'Precise interpolation'**
  String get labelPreciseInterpolation;

  /// No description provided for @labelInferToleranceFromCost.
  ///
  /// In en, this message translates to:
  /// **'Infer tolerance from cost'**
  String get labelInferToleranceFromCost;

  /// No description provided for @labelAllowPipeSeparator.
  ///
  /// In en, this message translates to:
  /// **'Allow pipe separator'**
  String get labelAllowPipeSeparator;

  /// No description provided for @labelAllowDeprecatedNone.
  ///
  /// In en, this message translates to:
  /// **'Allow deprecated none for tags and links'**
  String get labelAllowDeprecatedNone;

  /// No description provided for @labelInsertPythonPath.
  ///
  /// In en, this message translates to:
  /// **'Insert Python path'**
  String get labelInsertPythonPath;

  /// No description provided for @labelRenderCommas.
  ///
  /// In en, this message translates to:
  /// **'Render commas'**
  String get labelRenderCommas;

  /// No description provided for @labelTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get labelTitle;

  /// No description provided for @labelOperatingCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Operating currencies'**
  String get labelOperatingCurrencies;

  /// No description provided for @labelConversionCurrency.
  ///
  /// In en, this message translates to:
  /// **'Conversion currency'**
  String get labelConversionCurrency;

  /// No description provided for @labelBookingMethod.
  ///
  /// In en, this message translates to:
  /// **'Booking method'**
  String get labelBookingMethod;

  /// No description provided for @labelAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get labelAssets;

  /// No description provided for @labelLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get labelLiabilities;

  /// No description provided for @labelEquity.
  ///
  /// In en, this message translates to:
  /// **'Equity'**
  String get labelEquity;

  /// No description provided for @labelIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get labelIncome;

  /// No description provided for @labelExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get labelExpenses;

  /// No description provided for @labelDocumentsField.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get labelDocumentsField;

  /// No description provided for @labelToleranceMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Tolerance multiplier'**
  String get labelToleranceMultiplier;

  /// No description provided for @labelInferredToleranceMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Inferred tolerance multiplier'**
  String get labelInferredToleranceMultiplier;

  /// No description provided for @labelInferredToleranceDefaults.
  ///
  /// In en, this message translates to:
  /// **'Inferred tolerance defaults'**
  String get labelInferredToleranceDefaults;

  /// No description provided for @labelRoundingAccount.
  ///
  /// In en, this message translates to:
  /// **'Rounding account'**
  String get labelRoundingAccount;

  /// No description provided for @labelPreviousBalances.
  ///
  /// In en, this message translates to:
  /// **'Previous balances'**
  String get labelPreviousBalances;

  /// No description provided for @labelPreviousEarnings.
  ///
  /// In en, this message translates to:
  /// **'Previous earnings'**
  String get labelPreviousEarnings;

  /// No description provided for @labelPreviousConversions.
  ///
  /// In en, this message translates to:
  /// **'Previous conversions'**
  String get labelPreviousConversions;

  /// No description provided for @labelCurrentEarnings.
  ///
  /// In en, this message translates to:
  /// **'Current earnings'**
  String get labelCurrentEarnings;

  /// No description provided for @labelCurrentConversions.
  ///
  /// In en, this message translates to:
  /// **'Current conversions'**
  String get labelCurrentConversions;

  /// No description provided for @labelUnrealizedGains.
  ///
  /// In en, this message translates to:
  /// **'Unrealized gains'**
  String get labelUnrealizedGains;

  /// No description provided for @labelPluginMode.
  ///
  /// In en, this message translates to:
  /// **'Plugin processing mode'**
  String get labelPluginMode;

  /// No description provided for @labelLongStringMaxLines.
  ///
  /// In en, this message translates to:
  /// **'Long string max lines'**
  String get labelLongStringMaxLines;

  /// No description provided for @labelDisplayPrecision.
  ///
  /// In en, this message translates to:
  /// **'Display precision'**
  String get labelDisplayPrecision;

  /// No description provided for @addLabel.
  ///
  /// In en, this message translates to:
  /// **'Add {label}'**
  String addLabel(String label);

  /// No description provided for @keyLabel.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get keyLabel;

  /// No description provided for @numberLabel.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get numberLabel;

  /// No description provided for @valueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get valueLabel;

  /// No description provided for @closeLabel.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeLabel;

  /// No description provided for @hideGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get hideGenerated;

  /// No description provided for @hideTransaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get hideTransaction;

  /// No description provided for @hidePrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get hidePrice;

  /// No description provided for @hideBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get hideBalance;

  /// No description provided for @hideOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get hideOpen;

  /// No description provided for @hideClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get hideClose;

  /// No description provided for @hideCommodity.
  ///
  /// In en, this message translates to:
  /// **'Commodity'**
  String get hideCommodity;

  /// No description provided for @hidePad.
  ///
  /// In en, this message translates to:
  /// **'Pad'**
  String get hidePad;

  /// No description provided for @hideDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get hideDocument;

  /// No description provided for @hideNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get hideNote;

  /// No description provided for @hideEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get hideEvent;

  /// No description provided for @hideQuery.
  ///
  /// In en, this message translates to:
  /// **'Query'**
  String get hideQuery;

  /// No description provided for @hideCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get hideCustom;

  /// No description provided for @hideBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get hideBudget;

  /// No description provided for @hideBudgetOff.
  ///
  /// In en, this message translates to:
  /// **'Budget off'**
  String get hideBudgetOff;

  /// No description provided for @copyShowAdvancedSummary.
  ///
  /// In en, this message translates to:
  /// **'Shows options most ledgers leave at their defaults.'**
  String get copyShowAdvancedSummary;

  /// No description provided for @copyShowAdvancedDetail.
  ///
  /// In en, this message translates to:
  /// **'While this is off, those options are not shown. If the file already sets one, saving other settings leaves that line as it is.'**
  String get copyShowAdvancedDetail;

  /// No description provided for @copyAdvancedUiSummary.
  ///
  /// In en, this message translates to:
  /// **'Shows the plugins screen.'**
  String get copyAdvancedUiSummary;

  /// No description provided for @copyAdvancedUiDetail.
  ///
  /// In en, this message translates to:
  /// **'When this is on, a Plugins tab is available so you can turn plugins on, set them up, and change their order. When it is off, plugin lines stay in the file and the tab is hidden.'**
  String get copyAdvancedUiDetail;

  /// No description provided for @copyWriteDefaultsSummary.
  ///
  /// In en, this message translates to:
  /// **'Write every visible option, including values that match the defaults.'**
  String get copyWriteDefaultsSummary;

  /// No description provided for @copyWriteDefaultsDetail.
  ///
  /// In en, this message translates to:
  /// **'Normally the file only stores options that differ from Beancount\'s defaults. Turn this on to write the full set Guar is using. Options hidden by Advanced settings are left as they are.'**
  String get copyWriteDefaultsDetail;

  /// No description provided for @copyAllowUnopenedSummary.
  ///
  /// In en, this message translates to:
  /// **'Type any account in the transaction editor.'**
  String get copyAllowUnopenedSummary;

  /// No description provided for @copyAllowUnopenedDetail.
  ///
  /// In en, this message translates to:
  /// **'When this is on, the account pickers become plain text fields, so a posting can name an account no open directive shows, for example one a plugin such as autoopen opens. Accounts that nothing opens are still rejected when saving.'**
  String get copyAllowUnopenedDetail;

  /// No description provided for @copyIncludeInferredSummary.
  ///
  /// In en, this message translates to:
  /// **'List prices inferred from transactions.'**
  String get copyIncludeInferredSummary;

  /// No description provided for @copyIncludeInferredDetail.
  ///
  /// In en, this message translates to:
  /// **'The price database always shows explicit price directives. Turn this on to also list rates read from posting prices and costs in transactions, marked as inferred.'**
  String get copyIncludeInferredDetail;

  /// No description provided for @copyTitleSummary.
  ///
  /// In en, this message translates to:
  /// **'Name shown for this ledger.'**
  String get copyTitleSummary;

  /// No description provided for @copyTitleDetail.
  ///
  /// In en, this message translates to:
  /// **'Beancount uses this as the report title. Guar shows it on the ledger screen. The default is Beancount.'**
  String get copyTitleDetail;

  /// No description provided for @copyOperatingSummary.
  ///
  /// In en, this message translates to:
  /// **'Currencies this ledger uses day to day.'**
  String get copyOperatingSummary;

  /// No description provided for @copyOperatingDetail.
  ///
  /// In en, this message translates to:
  /// **'Add one code per line, such as USD or EUR. Queries that need a default currency use the first one. Leave the list empty if you have not chosen any.'**
  String get copyOperatingDetail;

  /// No description provided for @copyConversionSummary.
  ///
  /// In en, this message translates to:
  /// **'Currency used when amounts are converted.'**
  String get copyConversionSummary;

  /// No description provided for @copyConversionDetail.
  ///
  /// In en, this message translates to:
  /// **'Queries that convert to a single currency use this. NOTHING means no conversion currency is set. Use a code such as USD when you want conversions.'**
  String get copyConversionDetail;

  /// No description provided for @copyBookingSummary.
  ///
  /// In en, this message translates to:
  /// **'How a sale picks a lot when more than one could match.'**
  String get copyBookingSummary;

  /// No description provided for @copyBookingDetail.
  ///
  /// In en, this message translates to:
  /// **'STRICT requires the lot to be written out when several match. STRICT_WITH_SIZE also compares the lot size. NONE, FIFO, LIFO, HIFO, and AVERAGE pick a lot for you. The default is STRICT.'**
  String get copyBookingDetail;

  /// No description provided for @copyAssetsSummary.
  ///
  /// In en, this message translates to:
  /// **'Root name for accounts you own.'**
  String get copyAssetsSummary;

  /// No description provided for @copyAssetsDetail.
  ///
  /// In en, this message translates to:
  /// **'Every asset account starts with this name, then a colon. The default is Assets. Accounts already in the file are not renamed.'**
  String get copyAssetsDetail;

  /// No description provided for @copyLiabilitiesSummary.
  ///
  /// In en, this message translates to:
  /// **'Root name for accounts you owe.'**
  String get copyLiabilitiesSummary;

  /// No description provided for @copyLiabilitiesDetail.
  ///
  /// In en, this message translates to:
  /// **'Every liability account starts with this name. The default is Liabilities. Accounts already in the file are not renamed.'**
  String get copyLiabilitiesDetail;

  /// No description provided for @copyEquitySummary.
  ///
  /// In en, this message translates to:
  /// **'Root name for equity accounts.'**
  String get copyEquitySummary;

  /// No description provided for @copyEquityDetail.
  ///
  /// In en, this message translates to:
  /// **'Opening balances and retained earnings sit under this name unless you set those accounts yourself. The default is Equity.'**
  String get copyEquityDetail;

  /// No description provided for @copyIncomeSummary.
  ///
  /// In en, this message translates to:
  /// **'Root name for income accounts.'**
  String get copyIncomeSummary;

  /// No description provided for @copyIncomeDetail.
  ///
  /// In en, this message translates to:
  /// **'Every income account starts with this name. The default is Income. Unrealized gains sit under it unless you set that account yourself.'**
  String get copyIncomeDetail;

  /// No description provided for @copyExpensesSummary.
  ///
  /// In en, this message translates to:
  /// **'Root name for expense accounts.'**
  String get copyExpensesSummary;

  /// No description provided for @copyExpensesDetail.
  ///
  /// In en, this message translates to:
  /// **'Every expense account starts with this name. The default is Expenses.'**
  String get copyExpensesDetail;

  /// No description provided for @copyDocumentsSummary.
  ///
  /// In en, this message translates to:
  /// **'Folders checked for files linked by document directives.'**
  String get copyDocumentsSummary;

  /// No description provided for @copyDocumentsDetail.
  ///
  /// In en, this message translates to:
  /// **'Each line is a root folder. Booking checks that a document path lives under one of them. Guar does not open the file.'**
  String get copyDocumentsDetail;

  /// No description provided for @copyRenderCommasSummary.
  ///
  /// In en, this message translates to:
  /// **'Group digits with commas in Beancount\'s text output.'**
  String get copyRenderCommasSummary;

  /// No description provided for @copyRenderCommasDetail.
  ///
  /// In en, this message translates to:
  /// **'Beancount\'s own reports print 1,234.56 when this is on. Guar shows the digits that were recorded.'**
  String get copyRenderCommasDetail;

  /// No description provided for @copyRenderCommasWarning.
  ///
  /// In en, this message translates to:
  /// **'No effect in Guar. Amounts are not grouped with commas.'**
  String get copyRenderCommasWarning;

  /// No description provided for @copyMaxLinesSummary.
  ///
  /// In en, this message translates to:
  /// **'How many lines a long string may use in Beancount\'s printer.'**
  String get copyMaxLinesSummary;

  /// No description provided for @copyMaxLinesDetail.
  ///
  /// In en, this message translates to:
  /// **'This limits wrapping when Beancount prints the ledger. Guar saves strings as they were typed.'**
  String get copyMaxLinesDetail;

  /// No description provided for @copyMaxLinesWarning.
  ///
  /// In en, this message translates to:
  /// **'No effect in Guar. Strings are not wrapped on save.'**
  String get copyMaxLinesWarning;

  /// No description provided for @copyPluginModeSummary.
  ///
  /// In en, this message translates to:
  /// **'Whether checks run before or after plugins.'**
  String get copyPluginModeSummary;

  /// No description provided for @copyPluginModeDetail.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT runs document checks, padding, and balance checks around the plugins. RAW hands the plugins the entries before those steps. Use RAW only when a plugin expects it.'**
  String get copyPluginModeDetail;

  /// No description provided for @copyPythonPathSummary.
  ///
  /// In en, this message translates to:
  /// **'Add the ledger\'s folder to Python\'s import path.'**
  String get copyPythonPathSummary;

  /// No description provided for @copyPythonPathDetail.
  ///
  /// In en, this message translates to:
  /// **'Beancount does this so a Python plugin can import modules that sit next to the file. Guar does not run Python.'**
  String get copyPythonPathDetail;

  /// No description provided for @copyPythonPathWarning.
  ///
  /// In en, this message translates to:
  /// **'No effect in Guar. Python plugins are not run.'**
  String get copyPythonPathWarning;

  /// No description provided for @copyPipeSummary.
  ///
  /// In en, this message translates to:
  /// **'Allow a vertical bar between the payee and the narration.'**
  String get copyPipeSummary;

  /// No description provided for @copyPipeDetail.
  ///
  /// In en, this message translates to:
  /// **'Older files write the payee, a |, then the narration. Guar accepts that only when this is on. Beancount plans to remove the option.'**
  String get copyPipeDetail;

  /// No description provided for @copyDeprecatedNoneSummary.
  ///
  /// In en, this message translates to:
  /// **'Allow the word NONE where a tag or link was left out.'**
  String get copyDeprecatedNoneSummary;

  /// No description provided for @copyDeprecatedNoneDetail.
  ///
  /// In en, this message translates to:
  /// **'Older Beancount accepted NONE in that position. Guar\'s parser does not, whether this is on or off.'**
  String get copyDeprecatedNoneDetail;

  /// No description provided for @copyDeprecatedNoneWarning.
  ///
  /// In en, this message translates to:
  /// **'No effect in Guar. NONE is not accepted as a tag or link.'**
  String get copyDeprecatedNoneWarning;

  /// No description provided for @copyPreviousBalancesSummary.
  ///
  /// In en, this message translates to:
  /// **'Account that receives opening balances.'**
  String get copyPreviousBalancesSummary;

  /// No description provided for @copyPreviousBalancesDetail.
  ///
  /// In en, this message translates to:
  /// **'Queries that open the books on a date move the balance so far into this account. The default is Equity:Opening-Balances, and it follows the equity root when you have not set it.'**
  String get copyPreviousBalancesDetail;

  /// No description provided for @copyPreviousEarningsSummary.
  ///
  /// In en, this message translates to:
  /// **'Account for income and expenses from before the open date.'**
  String get copyPreviousEarningsSummary;

  /// No description provided for @copyPreviousEarningsDetail.
  ///
  /// In en, this message translates to:
  /// **'Queries that open or clear the books transfer prior income and expenses here. The default is Equity:Earnings:Previous.'**
  String get copyPreviousEarningsDetail;

  /// No description provided for @copyPreviousConversionsSummary.
  ///
  /// In en, this message translates to:
  /// **'Account for conversions from before the open date.'**
  String get copyPreviousConversionsSummary;

  /// No description provided for @copyPreviousConversionsDetail.
  ///
  /// In en, this message translates to:
  /// **'Queries that open the books park earlier currency conversions here. The default is Equity:Conversions:Previous.'**
  String get copyPreviousConversionsDetail;

  /// No description provided for @copyCurrentEarningsSummary.
  ///
  /// In en, this message translates to:
  /// **'Account for income and expenses when the books are closed.'**
  String get copyCurrentEarningsSummary;

  /// No description provided for @copyCurrentEarningsDetail.
  ///
  /// In en, this message translates to:
  /// **'Queries that close or clear the books transfer income and expenses here. The default is Equity:Earnings:Current.'**
  String get copyCurrentEarningsDetail;

  /// No description provided for @copyCurrentConversionsSummary.
  ///
  /// In en, this message translates to:
  /// **'Account for conversions when the books are closed.'**
  String get copyCurrentConversionsSummary;

  /// No description provided for @copyCurrentConversionsDetail.
  ///
  /// In en, this message translates to:
  /// **'Queries that close the books park currency conversions here. The default is Equity:Conversions:Current.'**
  String get copyCurrentConversionsDetail;

  /// No description provided for @copyUnrealizedSummary.
  ///
  /// In en, this message translates to:
  /// **'Account for unrealized gains.'**
  String get copyUnrealizedSummary;

  /// No description provided for @copyUnrealizedDetail.
  ///
  /// In en, this message translates to:
  /// **'Plugins that book unrealized gains use this income account. The default is Income:Earnings:Unrealized, and it follows the income root when you have not set it.'**
  String get copyUnrealizedDetail;

  /// No description provided for @copyRoundingSummary.
  ///
  /// In en, this message translates to:
  /// **'Account that absorbs leftover cents after interpolation.'**
  String get copyRoundingSummary;

  /// No description provided for @copyRoundingDetail.
  ///
  /// In en, this message translates to:
  /// **'When a transaction\'s postings do not add up by a fraction, the remainder is booked here. Leave this empty to skip that posting.'**
  String get copyRoundingDetail;

  /// No description provided for @copyPreciseSummary.
  ///
  /// In en, this message translates to:
  /// **'Interpolate missing amounts from the smallest tolerance.'**
  String get copyPreciseSummary;

  /// No description provided for @copyPreciseDetail.
  ///
  /// In en, this message translates to:
  /// **'When a posting amount is left blank, Guar fills it in. With this on, that fill uses the tighter tolerance. The default is off.'**
  String get copyPreciseDetail;

  /// No description provided for @copyInferCostSummary.
  ///
  /// In en, this message translates to:
  /// **'Guess balance tolerance from the cost, not only the units.'**
  String get copyInferCostSummary;

  /// No description provided for @copyInferCostDetail.
  ///
  /// In en, this message translates to:
  /// **'A balance check normally looks at the digits of the units. Turn this on to also consider the cost\'s digits. The default is off.'**
  String get copyInferCostDetail;

  /// No description provided for @copyToleranceSummary.
  ///
  /// In en, this message translates to:
  /// **'Newer name for the tolerance scale.'**
  String get copyToleranceSummary;

  /// No description provided for @copyToleranceDetail.
  ///
  /// In en, this message translates to:
  /// **'Beancount renamed the tolerance scale to tolerance_multiplier. Guar stores the value, and balance checks still read Inferred tolerance multiplier.'**
  String get copyToleranceDetail;

  /// No description provided for @copyToleranceWarning.
  ///
  /// In en, this message translates to:
  /// **'No effect in Guar. Balance checks use Inferred tolerance multiplier.'**
  String get copyToleranceWarning;

  /// No description provided for @copyInferredMultiplierSummary.
  ///
  /// In en, this message translates to:
  /// **'Scale for tolerance guessed from the number of digits.'**
  String get copyInferredMultiplierSummary;

  /// No description provided for @copyInferredMultiplierDetail.
  ///
  /// In en, this message translates to:
  /// **'A number with two decimal places allows about 0.01 times this scale. Guar uses it for balance checks and for filling in blank posting amounts. The default is 0.5.'**
  String get copyInferredMultiplierDetail;

  /// No description provided for @copyInferredDefaultsSummary.
  ///
  /// In en, this message translates to:
  /// **'Fixed tolerance for a currency, instead of guessing from the digits.'**
  String get copyInferredDefaultsSummary;

  /// No description provided for @copyInferredDefaultsDetail.
  ///
  /// In en, this message translates to:
  /// **'The key is * for every currency, or a code such as USD. The number is the tolerance, such as 0.01. These override the guessed tolerance for that currency.'**
  String get copyInferredDefaultsDetail;

  /// No description provided for @copyPrecisionSummary.
  ///
  /// In en, this message translates to:
  /// **'Digits Beancount prints for a currency.'**
  String get copyPrecisionSummary;

  /// No description provided for @copyPrecisionDetail.
  ///
  /// In en, this message translates to:
  /// **'The key is *, a currency such as USD, or a pair such as USD/EUR. The number is how many decimal places to print. Guar shows the digits that were recorded.'**
  String get copyPrecisionDetail;

  /// No description provided for @copyPrecisionWarning.
  ///
  /// In en, this message translates to:
  /// **'No effect in Guar. Amounts keep the digits that were recorded.'**
  String get copyPrecisionWarning;

  /// No description provided for @copyHideGeneratedSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves entries from plugins and padding off the list.'**
  String get copyHideGeneratedSummary;

  /// No description provided for @copyHideGeneratedDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides entries that plugins or balance padding added. What you wrote stays visible, and nothing is removed from the file.'**
  String get copyHideGeneratedDetail;

  /// No description provided for @copyHideTransactionSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves transactions off the list.'**
  String get copyHideTransactionSummary;

  /// No description provided for @copyHideTransactionDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides transactions on the ledger screen. They stay in the file.'**
  String get copyHideTransactionDetail;

  /// No description provided for @copyHidePriceSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves prices off the list.'**
  String get copyHidePriceSummary;

  /// No description provided for @copyHidePriceDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides price directives on the ledger screen. They stay in the file.'**
  String get copyHidePriceDetail;

  /// No description provided for @copyHideBalanceSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves balance assertions off the list.'**
  String get copyHideBalanceSummary;

  /// No description provided for @copyHideBalanceDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides balance assertions on the ledger screen. They stay in the file.'**
  String get copyHideBalanceDetail;

  /// No description provided for @copyHideOpenSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves account opens off the list.'**
  String get copyHideOpenSummary;

  /// No description provided for @copyHideOpenDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides open directives on the ledger screen. They stay in the file.'**
  String get copyHideOpenDetail;

  /// No description provided for @copyHideCloseSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves account closes off the list.'**
  String get copyHideCloseSummary;

  /// No description provided for @copyHideCloseDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides close directives on the ledger screen. They stay in the file.'**
  String get copyHideCloseDetail;

  /// No description provided for @copyHideCommoditySummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves commodities off the list.'**
  String get copyHideCommoditySummary;

  /// No description provided for @copyHideCommodityDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides commodity directives on the ledger screen. They stay in the file.'**
  String get copyHideCommodityDetail;

  /// No description provided for @copyHidePadSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves pads off the list.'**
  String get copyHidePadSummary;

  /// No description provided for @copyHidePadDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides pad directives on the ledger screen. They stay in the file.'**
  String get copyHidePadDetail;

  /// No description provided for @copyHideDocumentSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves documents off the list.'**
  String get copyHideDocumentSummary;

  /// No description provided for @copyHideDocumentDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides document directives on the ledger screen. They stay in the file.'**
  String get copyHideDocumentDetail;

  /// No description provided for @copyHideNoteSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves notes off the list.'**
  String get copyHideNoteSummary;

  /// No description provided for @copyHideNoteDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides notes on the ledger screen. They stay in the file.'**
  String get copyHideNoteDetail;

  /// No description provided for @copyHideEventSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves events off the list.'**
  String get copyHideEventSummary;

  /// No description provided for @copyHideEventDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides events on the ledger screen. They stay in the file.'**
  String get copyHideEventDetail;

  /// No description provided for @copyHideQuerySummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves queries off the list.'**
  String get copyHideQuerySummary;

  /// No description provided for @copyHideQueryDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides query directives on the ledger screen. They stay in the file.'**
  String get copyHideQueryDetail;

  /// No description provided for @copyHideCustomSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves custom directives off the list.'**
  String get copyHideCustomSummary;

  /// No description provided for @copyHideCustomDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides custom directives on the ledger screen. They stay in the file.'**
  String get copyHideCustomDetail;

  /// No description provided for @copyHideBudgetSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves budgets off the list.'**
  String get copyHideBudgetSummary;

  /// No description provided for @copyHideBudgetDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides budget directives on the ledger screen. They stay in the file.'**
  String get copyHideBudgetDetail;

  /// No description provided for @copyHideBudgetOffSummary.
  ///
  /// In en, this message translates to:
  /// **'Leaves budget-off directives off the list.'**
  String get copyHideBudgetOffSummary;

  /// No description provided for @copyHideBudgetOffDetail.
  ///
  /// In en, this message translates to:
  /// **'Hides budget-off directives on the ledger screen. They stay in the file.'**
  String get copyHideBudgetOffDetail;

  /// No description provided for @everyDirectiveHidden.
  ///
  /// In en, this message translates to:
  /// **'Every directive is hidden.'**
  String get everyDirectiveHidden;

  /// No description provided for @noDirectives.
  ///
  /// In en, this message translates to:
  /// **'This ledger has no directives.'**
  String get noDirectives;

  /// No description provided for @postingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} posting} other {{count} postings}}'**
  String postingsCount(int count);

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'(no description)'**
  String get noDescription;

  /// No description provided for @warningsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} warning} other {{count} warnings}}'**
  String warningsCount(int count);

  /// No description provided for @metaFrom.
  ///
  /// In en, this message translates to:
  /// **'from {account}'**
  String metaFrom(String account);

  /// No description provided for @typeAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get typeAssets;

  /// No description provided for @typeExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get typeExpenses;

  /// No description provided for @typeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get typeIncome;

  /// No description provided for @typeLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get typeLiabilities;

  /// No description provided for @typeEquity.
  ///
  /// In en, this message translates to:
  /// **'Equity'**
  String get typeEquity;

  /// No description provided for @closedDate.
  ///
  /// In en, this message translates to:
  /// **'Closed {date}'**
  String closedDate(String date);

  /// No description provided for @noActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity'**
  String get noActivity;

  /// No description provided for @moreCount.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String moreCount(int count);

  /// No description provided for @pluginsHint.
  ///
  /// In en, this message translates to:
  /// **'Plugins run from top to bottom. Drag a plugin to change that order.'**
  String get pluginsHint;

  /// No description provided for @noPluginsOn.
  ///
  /// In en, this message translates to:
  /// **'None of the plugins are turned on.'**
  String get noPluginsOn;

  /// No description provided for @availableTitle.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availableTitle;

  /// No description provided for @viewByDate.
  ///
  /// In en, this message translates to:
  /// **'By date'**
  String get viewByDate;

  /// No description provided for @viewByPair.
  ///
  /// In en, this message translates to:
  /// **'By pair'**
  String get viewByPair;

  /// No description provided for @priceInferred.
  ///
  /// In en, this message translates to:
  /// **'inferred'**
  String get priceInferred;

  /// No description provided for @noPrices.
  ///
  /// In en, this message translates to:
  /// **'This ledger has no prices.'**
  String get noPrices;

  /// No description provided for @pricesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} price} other {{count} prices}}'**
  String pricesCount(int count);

  /// No description provided for @timeframeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get timeframeAll;

  /// No description provided for @dragTooltip.
  ///
  /// In en, this message translates to:
  /// **'Drag to change the order'**
  String get dragTooltip;

  /// No description provided for @showDescription.
  ///
  /// In en, this message translates to:
  /// **'Show description'**
  String get showDescription;

  /// No description provided for @hideDescription.
  ///
  /// In en, this message translates to:
  /// **'Hide description'**
  String get hideDescription;

  /// No description provided for @unknownPlugin.
  ///
  /// In en, this message translates to:
  /// **'This plugin is not one of the built-in plugins. Its configuration is kept as written in the ledger.'**
  String get unknownPlugin;

  /// No description provided for @configLabel.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configLabel;

  /// No description provided for @addRule.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get addRule;

  /// No description provided for @addInsert.
  ///
  /// In en, this message translates to:
  /// **'Add insert'**
  String get addInsert;

  /// No description provided for @removeRule.
  ///
  /// In en, this message translates to:
  /// **'Remove rule'**
  String get removeRule;

  /// No description provided for @ruleName.
  ///
  /// In en, this message translates to:
  /// **'Rule name'**
  String get ruleName;

  /// No description provided for @accountPattern.
  ///
  /// In en, this message translates to:
  /// **'Account pattern'**
  String get accountPattern;

  /// No description provided for @accountTemplate.
  ///
  /// In en, this message translates to:
  /// **'Account template'**
  String get accountTemplate;

  /// No description provided for @currenciesTemplate.
  ///
  /// In en, this message translates to:
  /// **'Currencies template'**
  String get currenciesTemplate;

  /// No description provided for @enterDecimal.
  ///
  /// In en, this message translates to:
  /// **'Enter a decimal'**
  String get enterDecimal;

  /// No description provided for @enterWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number'**
  String get enterWholeNumber;

  /// No description provided for @openAccount.
  ///
  /// In en, this message translates to:
  /// **'Open account'**
  String get openAccount;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get editTransaction;

  /// No description provided for @editTransactionButton.
  ///
  /// In en, this message translates to:
  /// **'Save transaction'**
  String get editTransactionButton;

  /// No description provided for @editNeedsAdvanced.
  ///
  /// In en, this message translates to:
  /// **'This transaction uses advanced features. Turn on Advanced UI in Settings to edit it.'**
  String get editNeedsAdvanced;

  /// No description provided for @cannotEditGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated entries cannot be edited.'**
  String get cannotEditGenerated;

  /// No description provided for @labelDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get labelDate;

  /// No description provided for @labelAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get labelAccount;

  /// No description provided for @labelCurrenciesComma.
  ///
  /// In en, this message translates to:
  /// **'Currencies (comma separated)'**
  String get labelCurrenciesComma;

  /// No description provided for @bookingDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get bookingDefault;

  /// No description provided for @metadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get metadata;

  /// No description provided for @labelDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get labelDescription;

  /// No description provided for @labelPayee.
  ///
  /// In en, this message translates to:
  /// **'Payee (optional)'**
  String get labelPayee;

  /// No description provided for @statusTitle.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusTitle;

  /// No description provided for @postingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Postings'**
  String get postingsTitle;

  /// No description provided for @addPosting.
  ///
  /// In en, this message translates to:
  /// **'Add posting'**
  String get addPosting;

  /// No description provided for @labelFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get labelFile;

  /// No description provided for @addTransactionButton.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get addTransactionButton;

  /// No description provided for @autoBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'Leave one posting amount empty for auto-balancing.'**
  String get autoBalanceHint;

  /// No description provided for @needTwoAccounts.
  ///
  /// In en, this message translates to:
  /// **'You need at least two open accounts to create a transaction. Open them with the plus button first.'**
  String get needTwoAccounts;

  /// No description provided for @labelAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get labelAmount;

  /// No description provided for @autoHint.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoHint;

  /// No description provided for @fromAccount.
  ///
  /// In en, this message translates to:
  /// **'From account'**
  String get fromAccount;

  /// No description provided for @toAccount.
  ///
  /// In en, this message translates to:
  /// **'To account'**
  String get toAccount;

  /// No description provided for @tagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTitle;

  /// No description provided for @newTag.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get newTag;

  /// No description provided for @linksTitle.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get linksTitle;

  /// No description provided for @newLink.
  ///
  /// In en, this message translates to:
  /// **'New link'**
  String get newLink;

  /// No description provided for @labelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get labelName;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. trip-2024'**
  String get nameHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @customFlagEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Custom flag...'**
  String get customFlagEllipsis;

  /// No description provided for @customFlagTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Flag'**
  String get customFlagTitle;

  /// No description provided for @singleCharacter.
  ///
  /// In en, this message translates to:
  /// **'Single character'**
  String get singleCharacter;

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @notOpened.
  ///
  /// In en, this message translates to:
  /// **'{account} is not opened.'**
  String notOpened(String account);

  /// No description provided for @notOpenedHint.
  ///
  /// In en, this message translates to:
  /// **'Open the account, or turn a plugin on that opens it.'**
  String get notOpenedHint;

  /// No description provided for @turnPluginOn.
  ///
  /// In en, this message translates to:
  /// **'Turn a plugin on'**
  String get turnPluginOn;

  /// No description provided for @postingIndex.
  ///
  /// In en, this message translates to:
  /// **'Posting {number}'**
  String postingIndex(int number);

  /// No description provided for @noFlag.
  ///
  /// In en, this message translates to:
  /// **'No flag'**
  String get noFlag;

  /// No description provided for @noPrice.
  ///
  /// In en, this message translates to:
  /// **'No price'**
  String get noPrice;

  /// No description provided for @noCost.
  ///
  /// In en, this message translates to:
  /// **'No cost'**
  String get noCost;

  /// No description provided for @totalPrice.
  ///
  /// In en, this message translates to:
  /// **'Total price'**
  String get totalPrice;

  /// No description provided for @pricePerUnit.
  ///
  /// In en, this message translates to:
  /// **'Price per unit'**
  String get pricePerUnit;

  /// No description provided for @totalCost.
  ///
  /// In en, this message translates to:
  /// **'Total cost'**
  String get totalCost;

  /// No description provided for @costPerUnit.
  ///
  /// In en, this message translates to:
  /// **'Cost per unit'**
  String get costPerUnit;

  /// No description provided for @labelCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get labelCurrency;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @flagCompleted.
  ///
  /// In en, this message translates to:
  /// **'* (Completed)'**
  String get flagCompleted;

  /// No description provided for @flagIncomplete.
  ///
  /// In en, this message translates to:
  /// **'! (Incomplete)'**
  String get flagIncomplete;

  /// No description provided for @transactionMetaTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction metadata'**
  String get transactionMetaTitle;

  /// No description provided for @postingMetaTitle.
  ///
  /// In en, this message translates to:
  /// **'Posting metadata'**
  String get postingMetaTitle;

  /// No description provided for @keyHint.
  ///
  /// In en, this message translates to:
  /// **'key'**
  String get keyHint;

  /// No description provided for @valueHint.
  ///
  /// In en, this message translates to:
  /// **'value'**
  String get valueHint;

  /// No description provided for @couldNotWriteIncluded.
  ///
  /// In en, this message translates to:
  /// **'Could not write the included ledger file.'**
  String get couldNotWriteIncluded;

  /// No description provided for @couldNotSaveTransaction.
  ///
  /// In en, this message translates to:
  /// **'Could not save the transaction.'**
  String get couldNotSaveTransaction;

  /// No description provided for @couldNotUseFile.
  ///
  /// In en, this message translates to:
  /// **'Could not use that file.'**
  String get couldNotUseFile;

  /// No description provided for @couldNotReadTarget.
  ///
  /// In en, this message translates to:
  /// **'Could not read the target file.'**
  String get couldNotReadTarget;

  /// No description provided for @errInvalidAccountName.
  ///
  /// In en, this message translates to:
  /// **'not a valid account name'**
  String get errInvalidAccountName;

  /// No description provided for @errInvalidCurrencyCode.
  ///
  /// In en, this message translates to:
  /// **'not a valid currency code'**
  String get errInvalidCurrencyCode;

  /// No description provided for @errWholeNumberZeroOrGreater.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number zero or greater'**
  String get errWholeNumberZeroOrGreater;

  /// No description provided for @errEnterNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get errEnterNumber;

  /// No description provided for @errQuotesNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Quotes cannot be stored in an option value'**
  String get errQuotesNotAllowed;
}

class _GuarLocalizationsDelegate extends LocalizationsDelegate<GuarLocalizations> {
  const _GuarLocalizationsDelegate();

  @override
  Future<GuarLocalizations> load(Locale locale) {
    return SynchronousFuture<GuarLocalizations>(lookupGuarLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_GuarLocalizationsDelegate old) => false;
}

GuarLocalizations lookupGuarLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return GuarLocalizationsEn();
  }

  throw FlutterError(
    'GuarLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
