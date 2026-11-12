// Ledger settings: the chosen file stays in the app, and option edits are written back.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guar/l10n/gen/app_localizations.dart';
import 'package:guar/src/app_errors.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/ledger_option_draft.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar/src/settings_copy.dart';
import 'package:guar/src/settings_field.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';

// Native names for the languages Guar is translated to; they are not localized.
const Map<String, String> _languageNames = <String, String>{'en': 'English'};

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.session, super.key});

  final LedgerSession session;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, TextEditingController> _fields = <String, TextEditingController>{};
  final Map<String, FocusNode> _focus = <String, FocusNode>{};
  final List<TextEditingController> _documents = <TextEditingController>[];
  final List<FocusNode> _documentFocus = <FocusNode>[];
  final List<TextEditingController> _currencies = <TextEditingController>[];
  final List<FocusNode> _currencyFocus = <FocusNode>[];
  final List<TextEditingController> _precisionKeys = <TextEditingController>[];
  final List<TextEditingController> _precisionValues = <TextEditingController>[];
  final List<FocusNode> _precisionKeyFocus = <FocusNode>[];
  final List<FocusNode> _precisionValueFocus = <FocusNode>[];
  final List<TextEditingController> _toleranceKeys = <TextEditingController>[];
  final List<TextEditingController> _toleranceValues = <TextEditingController>[];
  final List<FocusNode> _toleranceKeyFocus = <FocusNode>[];
  final List<FocusNode> _toleranceValueFocus = <FocusNode>[];

  AccountPrefixes _baseline = const AccountPrefixes();
  LedgerOptions? _loadedOptions;
  bool _mute = false;
  bool _closed = false;
  bool _pumping = false;
  bool _again = false;
  int _seen = 0;
  OptionError? _fieldError;
  VoidCallback? _unbindFlush;

  LedgerDocument? get _document => widget.session.document;

  bool get _pickerBusy => widget.session.busy;

  bool get _busy => _pickerBusy || widget.session.loading;

  bool get _settled => widget.session.settled;

  List<String> _parseErrors = <String>[];
  Timer? _timer;

  bool _showAdvanced = false;
  bool _advancedUi = false;
  bool _writeDefaultOptions = false;
  bool _allowUnopenedAccounts = false;
  bool _includeInferredPrices = false;
  Set<String> _hidden = <String>{};
  String _language = '';
  bool _renderCommas = false;
  bool _insertPythonpath = false;
  bool _allowPipeSeparator = false;
  bool _allowDeprecatedNone = false;
  bool _usePreciseInterpolation = false;
  bool _inferToleranceFromCost = false;
  PluginProcessingMode _pluginMode = PluginProcessingMode.defaultMode;
  BookingMethod _booking = BookingMethod.strict;

  @override
  void initState() {
    super.initState();
    _unbindFlush = widget.session.bindFlush(flushPending);
    widget.session.addListener(_onSession);
    if (widget.session.generation != _seen) {
      _seen = widget.session.generation;
      _applyLoaded();
    }
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    widget.session.removeListener(_onSession);
    _unbindFlush?.call();
    for (final TextEditingController controller in _fields.values) {
      controller.dispose();
    }
    for (final FocusNode node in _focus.values) {
      node.dispose();
    }
    _disposeList(_documents, _documentFocus);
    _disposeList(_currencies, _currencyFocus);
    _disposePairs(_precisionKeys, _precisionValues, _precisionKeyFocus, _precisionValueFocus);
    _disposePairs(_toleranceKeys, _toleranceValues, _toleranceKeyFocus, _toleranceValueFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GuarLocalizations l10n = GuarLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final LedgerDocument? document = _document;
    final String? error = sessionMessage(widget.session, l10n);
    final OptionError? fieldError = _fieldError;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FilledButton(
              onPressed: _pickerBusy ? null : () => unawaited(_choose(widget.session.documents.openExisting)),
              child: Text(document?.displayName ?? l10n.openLedger),
            ),
            const SizedBox(height: 8),
            Text(l10n.pickLedgerHint, style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _pickerBusy ? null : () => unawaited(_choose(widget.session.documents.createNew)),
              child: Text(l10n.createLedger),
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(error, style: text.bodyMedium?.copyWith(color: colors.error)),
            ],
            if (_busy) ...<Widget>[const SizedBox(height: 16), const LinearProgressIndicator()],
            const SizedBox(height: 32),
            Text(l10n.optionsTitle, style: text.titleLarge),
            const SizedBox(height: 12),
            if (!_settled)
              const SizedBox.shrink()
            else if (document == null)
              Text(l10n.noLedgerSelected, style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant))
            else ...<Widget>[
              for (final String message in _parseErrors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(message, style: text.bodyMedium?.copyWith(color: colors.error)),
                ),
              if (fieldError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    optionErrorText(l10n, fieldError),
                    style: text.bodyMedium?.copyWith(color: colors.error),
                  ),
                ),
              _switch(
                'showAdvanced',
                l10n.labelAdvancedSettings,
                showAdvancedCopy(l10n),
                _showAdvanced,
                _setShowAdvanced,
              ),
              _section(l10n.sectionApp, l10n.appSummary),
              _menu<String>(
                'language',
                l10n.languageLabel,
                languageCopy(l10n),
                _language,
                _languageValues(),
                _languageLabel,
                (String value) => _toggle(() => _language = value),
              ),
              _switch(
                'advancedUi',
                l10n.labelAdvancedUi,
                advancedUiCopy(l10n),
                _advancedUi,
                (bool value) => _toggle(() => _advancedUi = value),
              ),
              _switch(
                'writeDefaultOptions',
                l10n.labelWriteDefaultOptions,
                writeDefaultsCopy(l10n),
                _writeDefaultOptions,
                (bool value) => _toggle(() => _writeDefaultOptions = value),
              ),
              _switch(
                'allowUnopenedAccounts',
                l10n.labelAllowUnopenedAccounts,
                allowUnopenedCopy(l10n),
                _allowUnopenedAccounts,
                (bool value) => _toggle(() => _allowUnopenedAccounts = value),
              ),
              _switch(
                'includeInferredPrices',
                l10n.labelIncludeInferredPrices,
                includeInferredCopy(l10n),
                _includeInferredPrices,
                (bool value) => _toggle(() => _includeInferredPrices = value),
              ),
              _section(l10n.sectionLedgerScreen, l10n.ledgerScreenSummary),
              for (final GuarHide item in GuarHide.values)
                _switch(
                  'hide-${item.token}',
                  hideLabel(item, l10n),
                  hideCopy(item, l10n),
                  _hidden.contains(item.token),
                  (bool value) => _setHidden(item.token, hidden: value),
                ),
              _section(l10n.sectionLedger, l10n.ledgerSummary),
              _textField('title', l10n.labelTitle, titleCopy(l10n)),
              _stringList(
                'currencies',
                l10n.labelOperatingCurrencies,
                operatingCopy(l10n),
                _currencies,
                _currencyFocus,
                _addCurrency,
                _removeCurrency,
              ),
              _textField('conversion', l10n.labelConversionCurrency, conversionCopy(l10n)),
              _menu<BookingMethod>(
                'booking',
                l10n.labelBookingMethod,
                bookingCopy(l10n),
                _booking,
                BookingMethod.values,
                _bookingLabel,
                (BookingMethod value) => _toggle(() => _booking = value),
              ),
              _section(l10n.sectionAccountNames, l10n.accountNamesSummary),
              _textField('assets', l10n.labelAssets, assetsCopy(l10n)),
              _textField('liabilities', l10n.labelLiabilities, liabilitiesCopy(l10n)),
              _textField('equity', l10n.labelEquity, equityCopy(l10n)),
              _textField('income', l10n.labelIncome, incomeCopy(l10n)),
              _textField('expenses', l10n.labelExpenses, expensesCopy(l10n)),
              if (_showAdvanced) ...<Widget>[
                _section(l10n.sectionDocuments, l10n.documentsSummary),
                _stringList(
                  'documents',
                  l10n.labelDocumentsField,
                  documentsCopy(l10n),
                  _documents,
                  _documentFocus,
                  _addDocument,
                  _removeDocument,
                ),
                _section(l10n.sectionBookingDetails, l10n.bookingDetailsSummary),
                _switch(
                  'precise',
                  l10n.labelPreciseInterpolation,
                  preciseCopy(l10n),
                  _usePreciseInterpolation,
                  (bool value) => _toggle(() => _usePreciseInterpolation = value),
                ),
                _switch(
                  'inferCost',
                  l10n.labelInferToleranceFromCost,
                  inferCostCopy(l10n),
                  _inferToleranceFromCost,
                  (bool value) => _toggle(() => _inferToleranceFromCost = value),
                ),
                _textField('tolerance', l10n.labelToleranceMultiplier, toleranceCopy(l10n)),
                _textField('inferredMultiplier', l10n.labelInferredToleranceMultiplier, inferredMultiplierCopy(l10n)),
                _pairList(
                  'tolerances',
                  l10n.labelInferredToleranceDefaults,
                  inferredDefaultsCopy(l10n),
                  _toleranceKeys,
                  _toleranceValues,
                  _toleranceKeyFocus,
                  _toleranceValueFocus,
                  _addTolerance,
                  _removeTolerance,
                ),
                _textField('rounding', l10n.labelRoundingAccount, roundingCopy(l10n)),
                _section(l10n.sectionSystemAccounts, l10n.systemAccountsSummary),
                _textField('previousBalances', l10n.labelPreviousBalances, previousBalancesCopy(l10n)),
                _textField('previousEarnings', l10n.labelPreviousEarnings, previousEarningsCopy(l10n)),
                _textField('previousConversions', l10n.labelPreviousConversions, previousConversionsCopy(l10n)),
                _textField('currentEarnings', l10n.labelCurrentEarnings, currentEarningsCopy(l10n)),
                _textField('currentConversions', l10n.labelCurrentConversions, currentConversionsCopy(l10n)),
                _textField('unrealizedGains', l10n.labelUnrealizedGains, unrealizedCopy(l10n)),
                _section(l10n.sectionPlugins, l10n.pluginsSummary),
                _menu<PluginProcessingMode>(
                  'pluginMode',
                  l10n.labelPluginMode,
                  pluginModeCopy(l10n),
                  _pluginMode,
                  PluginProcessingMode.values,
                  _pluginLabel,
                  (PluginProcessingMode value) => _toggle(() => _pluginMode = value),
                ),
                _section(l10n.sectionCompatibility, l10n.compatibilitySummary),
                _switch(
                  'pipe',
                  l10n.labelAllowPipeSeparator,
                  pipeCopy(l10n),
                  _allowPipeSeparator,
                  (bool value) => _toggle(() => _allowPipeSeparator = value),
                ),
                _switch(
                  'deprecatedNone',
                  l10n.labelAllowDeprecatedNone,
                  deprecatedNoneCopy(l10n),
                  _allowDeprecatedNone,
                  (bool value) => _toggle(() => _allowDeprecatedNone = value),
                ),
                _switch(
                  'pythonpath',
                  l10n.labelInsertPythonPath,
                  pythonPathCopy(l10n),
                  _insertPythonpath,
                  (bool value) => _toggle(() => _insertPythonpath = value),
                ),
                _switch(
                  'commas',
                  l10n.labelRenderCommas,
                  renderCommasCopy(l10n),
                  _renderCommas,
                  (bool value) => _toggle(() => _renderCommas = value),
                ),
                _textField('maxlines', l10n.labelLongStringMaxLines, maxLinesCopy(l10n)),
                _pairList(
                  'precision',
                  l10n.labelDisplayPrecision,
                  precisionCopy(l10n),
                  _precisionKeys,
                  _precisionValues,
                  _precisionKeyFocus,
                  _precisionValueFocus,
                  _addPrecision,
                  _removePrecision,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // An empty string means the phone language; a handwritten unknown code stays visible.
  List<String> _languageValues() {
    final List<String> known = <String>[
      for (final Locale locale in GuarLocalizations.supportedLocales) locale.languageCode,
    ];
    return <String>[
      '',
      ...known,
      if (_language.isNotEmpty && !known.contains(_language)) _language,
    ];
  }

  String _languageLabel(String value) {
    if (value.isEmpty) return GuarLocalizations.of(context).languageSystem;
    return _languageNames[value] ?? value;
  }

  Widget _section(String title, String summary) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: text.titleMedium),
          const SizedBox(height: 4),
          Text(summary, style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _textField(String id, String label, SettingCopy copy) => SettingBlock(
    helpKey: Key('help-$id'),
    label: label,
    copy: copy,
    child: TextFormField(
      key: Key(id),
      controller: _field(id),
      focusNode: _node(id),
      decoration: const InputDecoration(border: OutlineInputBorder()),
    ),
  );

  Widget _switch(String id, String label, SettingCopy copy, bool value, ValueChanged<bool> onChanged) => SettingSwitch(
    switchKey: Key(id),
    helpKey: Key('help-$id'),
    label: label,
    copy: copy,
    value: value,
    onChanged: onChanged,
  );

  Widget _menu<T>(
    String id,
    String label,
    SettingCopy copy,
    T value,
    List<T> values,
    String Function(T value) itemLabel,
    ValueChanged<T> onChanged,
  ) => SettingBlock(
    helpKey: Key('help-$id'),
    label: label,
    copy: copy,
    child: DropdownButtonFormField<T>(
      key: Key(id),
      initialValue: value,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: <DropdownMenuItem<T>>[
        for (final T item in values) DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))),
      ],
      onChanged: (T? next) {
        if (next != null) {
          onChanged(next);
        }
      },
    ),
  );

  Widget _stringList(
    String id,
    String label,
    SettingCopy copy,
    List<TextEditingController> controllers,
    List<FocusNode> nodes,
    VoidCallback onAdd,
    void Function(int index) onRemove,
  ) => SettingBlock(
    helpKey: Key('help-$id'),
    label: label,
    copy: copy,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < controllers.length; index++)
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: controllers[index],
                  focusNode: nodes[index],
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ),
              IconButton(onPressed: () => onRemove(index), icon: const Icon(Icons.close)),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onAdd, child: Text(GuarLocalizations.of(context).addLabel(label))),
        ),
      ],
    ),
  );

  Widget _pairList(
    String id,
    String label,
    SettingCopy copy,
    List<TextEditingController> keys,
    List<TextEditingController> values,
    List<FocusNode> keyNodes,
    List<FocusNode> valueNodes,
    VoidCallback onAdd,
    void Function(int index) onRemove,
  ) => SettingBlock(
    helpKey: Key('help-$id'),
    label: label,
    copy: copy,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < keys.length; index++)
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: keys[index],
                  focusNode: keyNodes[index],
                  decoration: InputDecoration(
                    labelText: GuarLocalizations.of(context).keyLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: values[index],
                  focusNode: valueNodes[index],
                  decoration: InputDecoration(
                    labelText: GuarLocalizations.of(context).numberLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(onPressed: () => onRemove(index), icon: const Icon(Icons.close)),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onAdd, child: Text(GuarLocalizations.of(context).addLabel(label))),
        ),
      ],
    ),
  );

  Future<void> _choose(Future<LedgerDocument?> Function() pick) => widget.session.choose(pick);

  void _onSession() {
    if (!mounted || _closed) return;
    if (_seen == widget.session.generation) {
      setState(() {});
      return;
    }
    _seen = widget.session.generation;
    _applyLoaded();
    setState(() {});
  }

  void _applyLoaded() {
    if (_document == null) {
      _parseErrors = <String>[];
      _fieldError = null;
      _loadedOptions = null;
      return;
    }
    final LoadedLedgerOptions? loaded = widget.session.snapshot?.options;
    if (loaded == null) {
      _parseErrors = <String>[];
      _fieldError = null;
      _loadedOptions = null;
      return;
    }
    _bind(loaded);
    _parseErrors = loaded.errors;
    _fieldError = null;
  }

  void _bind(LoadedLedgerOptions loaded) {
    final LedgerOptions options = loaded.options;
    _loadedOptions = options;
    _mute = true;
    _advancedUi = loaded.guar.advancedUi;
    _writeDefaultOptions = loaded.guar.writeDefaultOptions;
    _allowUnopenedAccounts = loaded.guar.allowUnopenedAccounts;
    _includeInferredPrices = loaded.guar.includeInferredPrices;
    _hidden = Set<String>.of(loaded.guar.hidden);
    _language = loaded.guar.language ?? '';
    _booking = options.bookingMethod;
    _pluginMode = options.pluginProcessingMode;
    _renderCommas = options.renderCommas;
    _insertPythonpath = options.insertPythonpath;
    _allowPipeSeparator = options.allowPipeSeparator;
    _allowDeprecatedNone = options.allowDeprecatedNoneForTagsAndLinks;
    _usePreciseInterpolation = options.usePreciseInterpolation;
    _inferToleranceFromCost = options.inferToleranceFromCost;
    _field('title').text = options.title;
    _replaceList(_documents, _documentFocus, options.documents);
    _replaceList(_currencies, _currencyFocus, options.operatingCurrency.map((Currency currency) => currency.name));
    _field('conversion').text = options.conversionCurrency.name;
    _field('maxlines').text = '${options.longStringMaxlines}';
    _field('assets').text = options.accountPrefixes.assets;
    _field('liabilities').text = options.accountPrefixes.liabilities;
    _field('equity').text = options.accountPrefixes.equity;
    _field('income').text = options.accountPrefixes.income;
    _field('expenses').text = options.accountPrefixes.expenses;
    _field('previousBalances').text = options.accountPreviousBalances.name;
    _field('previousEarnings').text = options.accountPreviousEarnings.name;
    _field('previousConversions').text = options.accountPreviousConversions.name;
    _field('currentEarnings').text = options.accountCurrentEarnings.name;
    _field('currentConversions').text = options.accountCurrentConversions.name;
    _field('unrealizedGains').text = options.accountUnrealizedGains.name;
    _field('rounding').text = options.accountRounding?.name ?? '';
    _field('tolerance').text = options.toleranceMultiplier.verbatim;
    _field('inferredMultiplier').text = options.inferredToleranceMultiplier.verbatim;
    _replacePairs(
      _toleranceKeys,
      _toleranceValues,
      _toleranceKeyFocus,
      _toleranceValueFocus,
      <({String key, String value})>[
        for (final InferredTolerance tolerance in options.inferredToleranceDefault)
          (key: _currencyKeyText(tolerance.key), value: tolerance.value.toString()),
      ],
    );
    _replacePairs(
      _precisionKeys,
      _precisionValues,
      _precisionKeyFocus,
      _precisionValueFocus,
      <({String key, String value})>[
        for (final DisplayPrecision precision in options.displayPrecision)
          (key: _precisionKeyText(precision.key), value: precision.value.toString()),
      ],
    );
    _baseline = options.accountPrefixes;
    _mute = false;
  }

  void _toggle(VoidCallback assign) {
    setState(assign);
    _flush();
  }

  void _setShowAdvanced(bool value) {
    if (_showAdvanced && !value) {
      _flush();
    }
    setState(() => _showAdvanced = value);
  }

  void _setHidden(String token, {required bool hidden}) {
    _toggle(() {
      final Set<String> next = <String>{..._hidden};
      if (hidden) {
        next.add(token);
      } else {
        next.remove(token);
      }
      _hidden = next;
    });
  }

  void _addDocument() => setState(() => _documents.add(_controller(_documentFocus)));

  void _addCurrency() => setState(() => _currencies.add(_controller(_currencyFocus)));

  void _addTolerance() =>
      setState(() => _addPair(_toleranceKeys, _toleranceValues, _toleranceKeyFocus, _toleranceValueFocus));

  void _addPrecision() =>
      setState(() => _addPair(_precisionKeys, _precisionValues, _precisionKeyFocus, _precisionValueFocus));

  void _removeDocument(int index) {
    setState(() => _drop(_documents, _documentFocus, index));
    _flush();
  }

  void _removeCurrency(int index) {
    setState(() => _drop(_currencies, _currencyFocus, index));
    _flush();
  }

  void _removeTolerance(int index) {
    setState(() => _dropPair(_toleranceKeys, _toleranceValues, _toleranceKeyFocus, _toleranceValueFocus, index));
    _flush();
  }

  void _removePrecision(int index) {
    setState(() => _dropPair(_precisionKeys, _precisionValues, _precisionKeyFocus, _precisionValueFocus, index));
    _flush();
  }

  TextEditingController _controller(List<FocusNode> nodes) {
    final TextEditingController controller = TextEditingController()..addListener(_schedule);
    nodes.add(_listen(FocusNode()));
    return controller;
  }

  void _addPair(
    List<TextEditingController> keys,
    List<TextEditingController> values,
    List<FocusNode> keyNodes,
    List<FocusNode> valueNodes,
  ) {
    keys.add(TextEditingController()..addListener(_schedule));
    values.add(TextEditingController()..addListener(_schedule));
    keyNodes.add(_listen(FocusNode()));
    valueNodes.add(_listen(FocusNode()));
  }

  void _drop(List<TextEditingController> controllers, List<FocusNode> nodes, int index) {
    controllers.removeAt(index).dispose();
    nodes.removeAt(index).dispose();
  }

  void _dropPair(
    List<TextEditingController> keys,
    List<TextEditingController> values,
    List<FocusNode> keyNodes,
    List<FocusNode> valueNodes,
    int index,
  ) {
    keys.removeAt(index).dispose();
    values.removeAt(index).dispose();
    keyNodes.removeAt(index).dispose();
    valueNodes.removeAt(index).dispose();
  }

  void _replaceList(List<TextEditingController> controllers, List<FocusNode> nodes, Iterable<String> values) {
    _disposeList(controllers, nodes);
    for (final String value in values) {
      final TextEditingController controller = TextEditingController(text: value)..addListener(_schedule);
      controllers.add(controller);
      nodes.add(_listen(FocusNode()));
    }
  }

  void _replacePairs(
    List<TextEditingController> keys,
    List<TextEditingController> values,
    List<FocusNode> keyNodes,
    List<FocusNode> valueNodes,
    List<({String key, String value})> rows,
  ) {
    _disposePairs(keys, values, keyNodes, valueNodes);
    for (final ({String key, String value}) row in rows) {
      keys.add(TextEditingController(text: row.key)..addListener(_schedule));
      values.add(TextEditingController(text: row.value)..addListener(_schedule));
      keyNodes.add(_listen(FocusNode()));
      valueNodes.add(_listen(FocusNode()));
    }
  }

  void _disposeList(List<TextEditingController> controllers, List<FocusNode> nodes) {
    for (final TextEditingController controller in controllers) {
      controller.dispose();
    }
    for (final FocusNode node in nodes) {
      node.dispose();
    }
    controllers.clear();
    nodes.clear();
  }

  void _disposePairs(
    List<TextEditingController> keys,
    List<TextEditingController> values,
    List<FocusNode> keyNodes,
    List<FocusNode> valueNodes,
  ) {
    _disposeList(keys, keyNodes);
    _disposeList(values, valueNodes);
  }

  TextEditingController _field(String id) =>
      _fields.putIfAbsent(id, () => TextEditingController()..addListener(_schedule));

  FocusNode _node(String id) => _focus.putIfAbsent(id, () => _listen(FocusNode()));

  FocusNode _listen(FocusNode node) {
    node.addListener(() {
      if (!node.hasFocus) {
        scheduleMicrotask(() {
          if (!_closed) {
            _flush();
          }
        });
      }
    });
    return node;
  }

  void _schedule() {
    if (_closed || _mute || _document == null) {
      return;
    }
    _timer?.cancel();
    _timer = Timer(ledgerOptionSaveDelay, () => unawaited(_pump()));
  }

  void _flush() {
    if (_closed || _mute || _document == null) {
      return;
    }
    _timer?.cancel();
    unawaited(_pump());
  }

  Future<void> flushPending() {
    final Timer? timer = _timer;
    if (_closed || timer == null || !timer.isActive) return Future<void>.value();
    timer.cancel();
    _timer = null;
    return _pump();
  }

  Future<void> _pump() async {
    if (_document == null) {
      return;
    }
    if (_pumping) {
      _again = true;
      return;
    }
    _pumping = true;
    try {
      do {
        _again = false;
        await _saveOnce();
      } while (_again && !_closed);
    } finally {
      _pumping = false;
    }
  }

  Future<void> _saveOnce() async {
    final LedgerDocument? document = _document;
    if (document == null) {
      return;
    }
    final bool showAdvanced = _showAdvanced;
    final DraftedOptions drafted = draftLedgerOptions(_inputs(showAdvanced: showAdvanced));
    final OptionError? error = drafted.error;
    final LedgerOptions? options = drafted.options;
    if (error != null || options == null) {
      if (mounted) {
        setState(() => _fieldError = error);
      }
      return;
    }
    _mute = true;
    for (final MapEntry<String, String> entry in drafted.accounts.entries) {
      final TextEditingController? controller = _fields[entry.key];
      if (controller != null && controller.text != entry.value) {
        controller.text = entry.value;
      }
    }
    _mute = false;
    _baseline = options.accountPrefixes;
    if (mounted && _fieldError != null) {
      setState(() => _fieldError = null);
    }
    await widget.session.saveOptions(
      options,
      GuarOptions(
        advancedUi: _advancedUi,
        writeDefaultOptions: _writeDefaultOptions,
        allowUnopenedAccounts: _allowUnopenedAccounts,
        includeInferredPrices: _includeInferredPrices,
        hidden: _hidden,
        language: _language.isEmpty ? null : _language,
      ),
      preserveKeys: showAdvanced ? const <String>{} : advancedOptionKeys,
    );
  }

  OptionInputs _inputs({required bool showAdvanced}) {
    final LedgerOptions? frozen = showAdvanced ? null : _loadedOptions;
    return OptionInputs(
      title: _field('title').text,
      documents: frozen != null ? List<String>.of(frozen.documents) : _texts(_documents),
      operatingCurrencies: _texts(_currencies),
      conversionCurrency: _field('conversion').text,
      renderCommas: frozen?.renderCommas ?? _renderCommas,
      longStringMaxlines: frozen != null ? '${frozen.longStringMaxlines}' : _field('maxlines').text,
      pluginProcessingMode: frozen?.pluginProcessingMode ?? _pluginMode,
      insertPythonpath: frozen?.insertPythonpath ?? _insertPythonpath,
      allowPipeSeparator: frozen?.allowPipeSeparator ?? _allowPipeSeparator,
      allowDeprecatedNoneForTagsAndLinks: frozen?.allowDeprecatedNoneForTagsAndLinks ?? _allowDeprecatedNone,
      assets: _field('assets').text,
      liabilities: _field('liabilities').text,
      equity: _field('equity').text,
      income: _field('income').text,
      expenses: _field('expenses').text,
      previousBalances: frozen?.accountPreviousBalances.name ?? _field('previousBalances').text,
      previousEarnings: frozen?.accountPreviousEarnings.name ?? _field('previousEarnings').text,
      previousConversions: frozen?.accountPreviousConversions.name ?? _field('previousConversions').text,
      currentEarnings: frozen?.accountCurrentEarnings.name ?? _field('currentEarnings').text,
      currentConversions: frozen?.accountCurrentConversions.name ?? _field('currentConversions').text,
      unrealizedGains: frozen?.accountUnrealizedGains.name ?? _field('unrealizedGains').text,
      rounding: frozen != null ? (frozen.accountRounding?.name ?? '') : _field('rounding').text,
      bookingMethod: _booking,
      usePreciseInterpolation: frozen?.usePreciseInterpolation ?? _usePreciseInterpolation,
      inferToleranceFromCost: frozen?.inferToleranceFromCost ?? _inferToleranceFromCost,
      toleranceMultiplier: frozen?.toleranceMultiplier.verbatim ?? _field('tolerance').text,
      inferredToleranceMultiplier: frozen?.inferredToleranceMultiplier.verbatim ?? _field('inferredMultiplier').text,
      inferredTolerances: frozen != null ? _toleranceRows(frozen) : _pairs(_toleranceKeys, _toleranceValues),
      displayPrecisions: frozen != null ? _precisionRows(frozen) : _pairs(_precisionKeys, _precisionValues),
      baselinePrefixes: _baseline,
    );
  }

  List<String> _texts(List<TextEditingController> controllers) => <String>[
    for (final TextEditingController controller in controllers) controller.text,
  ];

  List<({String key, String value})> _pairs(List<TextEditingController> keys, List<TextEditingController> values) =>
      <({String key, String value})>[
        for (int index = 0; index < keys.length; index++) (key: keys[index].text, value: values[index].text),
      ];

  List<({String key, String value})> _toleranceRows(LedgerOptions options) => <({String key, String value})>[
    for (final InferredTolerance tolerance in options.inferredToleranceDefault)
      (key: _currencyKeyText(tolerance.key), value: tolerance.value.toString()),
  ];

  List<({String key, String value})> _precisionRows(LedgerOptions options) => <({String key, String value})>[
    for (final DisplayPrecision precision in options.displayPrecision)
      (key: _precisionKeyText(precision.key), value: precision.value.toString()),
  ];
}

String _bookingLabel(BookingMethod method) => switch (method) {
  BookingMethod.strict => 'STRICT',
  BookingMethod.strictWithSize => 'STRICT_WITH_SIZE',
  BookingMethod.none => 'NONE',
  BookingMethod.average => 'AVERAGE',
  BookingMethod.fifo => 'FIFO',
  BookingMethod.hifo => 'HIFO',
  BookingMethod.lifo => 'LIFO',
};

String _pluginLabel(PluginProcessingMode mode) => switch (mode) {
  PluginProcessingMode.defaultMode => 'DEFAULT',
  PluginProcessingMode.raw => 'RAW',
};

String _currencyKeyText(CurrencyKey key) => switch (key) {
  CurrencyKeyAll() => '*',
  CurrencyKeyCurrency(:final Currency value) => value.name,
};

String _precisionKeyText(DisplayPrecisionKey key) => switch (key) {
  DisplayPrecisionAll() => '*',
  DisplayPrecisionCurrency(:final Currency value) => value.name,
  DisplayPrecisionPair(:final Currency first, :final Currency second) => '${first.name}/${second.name}',
};
