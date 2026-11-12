// Explanations for ledger settings, and which option keys stay untouched while advanced is off.

import 'package:guar/l10n/gen/app_localizations.dart';
import 'package:guar_book/guar_book.dart' show GuarHide;

typedef SettingCopy = ({String summary, String detail, String? warning});

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

SettingCopy showAdvancedCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyShowAdvancedSummary, detail: l10n.copyShowAdvancedDetail, warning: null);

SettingCopy advancedUiCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyAdvancedUiSummary, detail: l10n.copyAdvancedUiDetail, warning: null);

SettingCopy writeDefaultsCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyWriteDefaultsSummary, detail: l10n.copyWriteDefaultsDetail, warning: null);

SettingCopy allowUnopenedCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyAllowUnopenedSummary, detail: l10n.copyAllowUnopenedDetail, warning: null);

SettingCopy includeInferredCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyIncludeInferredSummary, detail: l10n.copyIncludeInferredDetail, warning: null);

SettingCopy titleCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyTitleSummary, detail: l10n.copyTitleDetail, warning: null);

SettingCopy operatingCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyOperatingSummary, detail: l10n.copyOperatingDetail, warning: null);

SettingCopy conversionCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyConversionSummary, detail: l10n.copyConversionDetail, warning: null);

SettingCopy bookingCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyBookingSummary, detail: l10n.copyBookingDetail, warning: null);

SettingCopy assetsCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyAssetsSummary, detail: l10n.copyAssetsDetail, warning: null);

SettingCopy liabilitiesCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyLiabilitiesSummary, detail: l10n.copyLiabilitiesDetail, warning: null);

SettingCopy equityCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyEquitySummary, detail: l10n.copyEquityDetail, warning: null);

SettingCopy incomeCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyIncomeSummary, detail: l10n.copyIncomeDetail, warning: null);

SettingCopy expensesCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyExpensesSummary, detail: l10n.copyExpensesDetail, warning: null);

SettingCopy documentsCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyDocumentsSummary, detail: l10n.copyDocumentsDetail, warning: null);

SettingCopy renderCommasCopy(GuarLocalizations l10n) => (
  summary: l10n.copyRenderCommasSummary,
  detail: l10n.copyRenderCommasDetail,
  warning: l10n.copyRenderCommasWarning,
);

SettingCopy maxLinesCopy(GuarLocalizations l10n) => (
  summary: l10n.copyMaxLinesSummary,
  detail: l10n.copyMaxLinesDetail,
  warning: l10n.copyMaxLinesWarning,
);

SettingCopy pluginModeCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyPluginModeSummary, detail: l10n.copyPluginModeDetail, warning: null);

SettingCopy pythonPathCopy(GuarLocalizations l10n) => (
  summary: l10n.copyPythonPathSummary,
  detail: l10n.copyPythonPathDetail,
  warning: l10n.copyPythonPathWarning,
);

SettingCopy pipeCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyPipeSummary, detail: l10n.copyPipeDetail, warning: null);

SettingCopy deprecatedNoneCopy(GuarLocalizations l10n) => (
  summary: l10n.copyDeprecatedNoneSummary,
  detail: l10n.copyDeprecatedNoneDetail,
  warning: l10n.copyDeprecatedNoneWarning,
);

SettingCopy previousBalancesCopy(GuarLocalizations l10n) => (
  summary: l10n.copyPreviousBalancesSummary,
  detail: l10n.copyPreviousBalancesDetail,
  warning: null,
);

SettingCopy previousEarningsCopy(GuarLocalizations l10n) => (
  summary: l10n.copyPreviousEarningsSummary,
  detail: l10n.copyPreviousEarningsDetail,
  warning: null,
);

SettingCopy previousConversionsCopy(GuarLocalizations l10n) => (
  summary: l10n.copyPreviousConversionsSummary,
  detail: l10n.copyPreviousConversionsDetail,
  warning: null,
);

SettingCopy currentEarningsCopy(GuarLocalizations l10n) => (
  summary: l10n.copyCurrentEarningsSummary,
  detail: l10n.copyCurrentEarningsDetail,
  warning: null,
);

SettingCopy currentConversionsCopy(GuarLocalizations l10n) => (
  summary: l10n.copyCurrentConversionsSummary,
  detail: l10n.copyCurrentConversionsDetail,
  warning: null,
);

SettingCopy unrealizedCopy(GuarLocalizations l10n) => (
  summary: l10n.copyUnrealizedSummary,
  detail: l10n.copyUnrealizedDetail,
  warning: null,
);

SettingCopy roundingCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyRoundingSummary, detail: l10n.copyRoundingDetail, warning: null);

SettingCopy preciseCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyPreciseSummary, detail: l10n.copyPreciseDetail, warning: null);

SettingCopy inferCostCopy(GuarLocalizations l10n) =>
    (summary: l10n.copyInferCostSummary, detail: l10n.copyInferCostDetail, warning: null);

SettingCopy toleranceCopy(GuarLocalizations l10n) => (
  summary: l10n.copyToleranceSummary,
  detail: l10n.copyToleranceDetail,
  warning: l10n.copyToleranceWarning,
);

SettingCopy inferredMultiplierCopy(GuarLocalizations l10n) => (
  summary: l10n.copyInferredMultiplierSummary,
  detail: l10n.copyInferredMultiplierDetail,
  warning: null,
);

SettingCopy inferredDefaultsCopy(GuarLocalizations l10n) => (
  summary: l10n.copyInferredDefaultsSummary,
  detail: l10n.copyInferredDefaultsDetail,
  warning: null,
);

SettingCopy precisionCopy(GuarLocalizations l10n) => (
  summary: l10n.copyPrecisionSummary,
  detail: l10n.copyPrecisionDetail,
  warning: l10n.copyPrecisionWarning,
);

SettingCopy languageCopy(GuarLocalizations l10n) =>
    (summary: l10n.languageSummary, detail: l10n.languageDetail, warning: null);

SettingCopy hideCopy(GuarHide item, GuarLocalizations l10n) => switch (item) {
  GuarHide.generated => (
    summary: l10n.copyHideGeneratedSummary,
    detail: l10n.copyHideGeneratedDetail,
    warning: null,
  ),
  GuarHide.transaction => (
    summary: l10n.copyHideTransactionSummary,
    detail: l10n.copyHideTransactionDetail,
    warning: null,
  ),
  GuarHide.price => (
    summary: l10n.copyHidePriceSummary,
    detail: l10n.copyHidePriceDetail,
    warning: null,
  ),
  GuarHide.balance => (
    summary: l10n.copyHideBalanceSummary,
    detail: l10n.copyHideBalanceDetail,
    warning: null,
  ),
  GuarHide.open => (summary: l10n.copyHideOpenSummary, detail: l10n.copyHideOpenDetail, warning: null),
  GuarHide.close => (summary: l10n.copyHideCloseSummary, detail: l10n.copyHideCloseDetail, warning: null),
  GuarHide.commodity => (
    summary: l10n.copyHideCommoditySummary,
    detail: l10n.copyHideCommodityDetail,
    warning: null,
  ),
  GuarHide.pad => (summary: l10n.copyHidePadSummary, detail: l10n.copyHidePadDetail, warning: null),
  GuarHide.document => (
    summary: l10n.copyHideDocumentSummary,
    detail: l10n.copyHideDocumentDetail,
    warning: null,
  ),
  GuarHide.note => (summary: l10n.copyHideNoteSummary, detail: l10n.copyHideNoteDetail, warning: null),
  GuarHide.event => (summary: l10n.copyHideEventSummary, detail: l10n.copyHideEventDetail, warning: null),
  GuarHide.query => (summary: l10n.copyHideQuerySummary, detail: l10n.copyHideQueryDetail, warning: null),
  GuarHide.custom => (summary: l10n.copyHideCustomSummary, detail: l10n.copyHideCustomDetail, warning: null),
  GuarHide.budget => (summary: l10n.copyHideBudgetSummary, detail: l10n.copyHideBudgetDetail, warning: null),
  GuarHide.budgetOff => (
    summary: l10n.copyHideBudgetOffSummary,
    detail: l10n.copyHideBudgetOffDetail,
    warning: null,
  ),
};

String hideLabel(GuarHide item, GuarLocalizations l10n) => switch (item) {
  GuarHide.generated => l10n.hideGenerated,
  GuarHide.transaction => l10n.hideTransaction,
  GuarHide.price => l10n.hidePrice,
  GuarHide.balance => l10n.hideBalance,
  GuarHide.open => l10n.hideOpen,
  GuarHide.close => l10n.hideClose,
  GuarHide.commodity => l10n.hideCommodity,
  GuarHide.pad => l10n.hidePad,
  GuarHide.document => l10n.hideDocument,
  GuarHide.note => l10n.hideNote,
  GuarHide.event => l10n.hideEvent,
  GuarHide.query => l10n.hideQuery,
  GuarHide.custom => l10n.hideCustom,
  GuarHide.budget => l10n.hideBudget,
  GuarHide.budgetOff => l10n.hideBudgetOff,
};
