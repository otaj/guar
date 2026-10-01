// Ledger settings: the chosen file stays in the app, and option edits are written back.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar/src/ledger_option_draft.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';

const Duration ledgerOptionSaveDelay = Duration(milliseconds: 500);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.documents, super.key});

  final LedgerDocuments documents;

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

  LedgerDocument? _document;
  String _source = '';
  AccountPrefixes _baseline = const AccountPrefixes();
  bool _busy = false;
  bool _settled = false;
  bool _mute = false;
  bool _closed = false;
  bool _pumping = false;
  bool _again = false;
  int _epoch = 0;
  String? _error;
  String? _fieldError;
  List<String> _parseErrors = <String>[];
  Timer? _timer;

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
    unawaited(_load());
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
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
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final LedgerDocument? document = _document;
    final String? error = _error;
    final String? fieldError = _fieldError;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FilledButton(
                onPressed: _busy ? null : () => unawaited(_choose(widget.documents.openExisting)),
                child: Text(document?.displayName ?? 'Open a ledger'),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the root ledger file. That choice stays in the app.',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _busy ? null : () => unawaited(_choose(widget.documents.createNew)),
                child: const Text('Create a new ledger'),
              ),
              if (error != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(error, style: text.bodyMedium?.copyWith(color: colors.error)),
              ],
              if (_busy) ...<Widget>[const SizedBox(height: 16), const LinearProgressIndicator()],
              const SizedBox(height: 32),
              Text('Options', style: text.titleLarge),
              const SizedBox(height: 12),
              if (!_settled)
                const SizedBox.shrink()
              else if (document == null)
                Text('No ledger is selected.', style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant))
              else ...<Widget>[
                for (final String message in _parseErrors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(message, style: text.bodyMedium?.copyWith(color: colors.error)),
                  ),
                if (fieldError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(fieldError, style: text.bodyMedium?.copyWith(color: colors.error)),
                  ),
                _textField('title', 'Title'),
                _stringList('Documents', _documents, _documentFocus, _addDocument, _removeDocument),
                _stringList('Operating currencies', _currencies, _currencyFocus, _addCurrency, _removeCurrency),
                _textField('conversion', 'Conversion currency', key: const Key('conversion')),
                _switch('Render commas', _renderCommas, (bool value) => _toggle(() => _renderCommas = value)),
                _textField('maxlines', 'Long string max lines'),
                _menu<PluginProcessingMode>(
                  'Plugin processing mode',
                  _pluginMode,
                  PluginProcessingMode.values,
                  _pluginLabel,
                  (PluginProcessingMode value) => _toggle(() => _pluginMode = value),
                ),
                _switch(
                  'Insert pythonpath',
                  _insertPythonpath,
                  (bool value) => _toggle(() => _insertPythonpath = value),
                ),
                _switch(
                  'Allow pipe separator',
                  _allowPipeSeparator,
                  (bool value) => _toggle(() => _allowPipeSeparator = value),
                ),
                _switch(
                  'Allow deprecated none for tags and links',
                  _allowDeprecatedNone,
                  (bool value) => _toggle(() => _allowDeprecatedNone = value),
                ),
                _textField('assets', 'Assets'),
                _textField('liabilities', 'Liabilities'),
                _textField('equity', 'Equity'),
                _textField('income', 'Income'),
                _textField('expenses', 'Expenses'),
                _textField('previousBalances', 'Previous balances'),
                _textField('previousEarnings', 'Previous earnings'),
                _textField('previousConversions', 'Previous conversions'),
                _textField('currentEarnings', 'Current earnings'),
                _textField('currentConversions', 'Current conversions'),
                _textField('unrealizedGains', 'Unrealized gains'),
                _textField('rounding', 'Rounding account'),
                _menu<BookingMethod>(
                  'Booking method',
                  _booking,
                  BookingMethod.values,
                  _bookingLabel,
                  (BookingMethod value) => _toggle(() => _booking = value),
                  key: const Key('booking'),
                ),
                _switch(
                  'Precise interpolation',
                  _usePreciseInterpolation,
                  (bool value) => _toggle(() => _usePreciseInterpolation = value),
                ),
                _switch(
                  'Infer tolerance from cost',
                  _inferToleranceFromCost,
                  (bool value) => _toggle(() => _inferToleranceFromCost = value),
                ),
                _textField('tolerance', 'Tolerance multiplier'),
                _textField('inferredMultiplier', 'Inferred tolerance multiplier'),
                _pairList(
                  'Inferred tolerance defaults',
                  _toleranceKeys,
                  _toleranceValues,
                  _toleranceKeyFocus,
                  _toleranceValueFocus,
                  'Key',
                  'Number',
                  _addTolerance,
                  _removeTolerance,
                ),
                _pairList(
                  'Display precision',
                  _precisionKeys,
                  _precisionValues,
                  _precisionKeyFocus,
                  _precisionValueFocus,
                  'Key',
                  'Number',
                  _addPrecision,
                  _removePrecision,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(String id, String label, {Key? key}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: key ?? Key(id),
      controller: _field(id),
      focusNode: _node(id),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    ),
  );

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(label), value: value, onChanged: onChanged);

  Widget _menu<T>(
    String label,
    T value,
    List<T> values,
    String Function(T value) itemLabel,
    ValueChanged<T> onChanged, {
    Key? key,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      key: key ?? Key(label),
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
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
    String label,
    List<TextEditingController> controllers,
    List<FocusNode> nodes,
    VoidCallback onAdd,
    void Function(int index) onRemove,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(label, style: Theme.of(context).textTheme.titleMedium),
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
        child: TextButton(onPressed: onAdd, child: Text('Add $label')),
      ),
    ],
  );

  Widget _pairList(
    String label,
    List<TextEditingController> keys,
    List<TextEditingController> values,
    List<FocusNode> keyNodes,
    List<FocusNode> valueNodes,
    String keyLabel,
    String valueLabel,
    VoidCallback onAdd,
    void Function(int index) onRemove,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(label, style: Theme.of(context).textTheme.titleMedium),
      for (int index = 0; index < keys.length; index++)
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: keys[index],
                focusNode: keyNodes[index],
                decoration: InputDecoration(labelText: keyLabel, border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: values[index],
                focusNode: valueNodes[index],
                decoration: InputDecoration(labelText: valueLabel, border: const OutlineInputBorder()),
              ),
            ),
            IconButton(onPressed: () => onRemove(index), icon: const Icon(Icons.close)),
          ],
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: onAdd, child: Text('Add $label')),
      ),
    ],
  );

  Future<void> _load() async {
    final int epoch = _epoch;
    try {
      final LedgerDocument? document = await widget.documents.current();
      if (!mounted || epoch != _epoch) {
        return;
      }
      await _show(document, epoch);
    } on PlatformException catch (error) {
      if (!mounted || epoch != _epoch) {
        return;
      }
      setState(() {
        _error = _message(error);
        _settled = true;
      });
    }
  }

  Future<void> _choose(Future<LedgerDocument?> Function() pick) async {
    final int epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final LedgerDocument? document = await pick();
      if (!mounted || epoch != _epoch) {
        return;
      }
      if (document == null) {
        setState(() {
          _busy = false;
          _settled = true;
        });
        return;
      }
      setState(() => _busy = false);
      await _show(document, epoch);
    } on PlatformException catch (error) {
      if (!mounted || epoch != _epoch) {
        return;
      }
      setState(() {
        _busy = false;
        _settled = true;
        _error = _message(error);
      });
    }
  }

  Future<void> _show(LedgerDocument? document, int epoch) async {
    if (document == null) {
      if (!mounted || epoch != _epoch) {
        return;
      }
      setState(() {
        _document = null;
        _settled = true;
        _parseErrors = <String>[];
      });
      return;
    }
    final String source;
    try {
      source = await widget.documents.read(document);
    } on PlatformException catch (error) {
      if (!mounted || epoch != _epoch) {
        return;
      }
      setState(() {
        _busy = false;
        _settled = true;
        _error = _message(error);
      });
      return;
    }
    if (!mounted || epoch != _epoch) {
      return;
    }
    final LoadedLedgerOptions loaded = readLedgerOptions(source);
    _bind(loaded.options);
    setState(() {
      _document = document;
      _source = source;
      _parseErrors = loaded.errors;
      _fieldError = null;
      _settled = true;
      _baseline = loaded.options.accountPrefixes;
    });
  }

  void _bind(LedgerOptions options) {
    _mute = true;
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
    final DraftedOptions drafted = draftLedgerOptions(_inputs());
    final String? error = drafted.error;
    final LedgerOptions? options = drafted.options;
    if (error != null || options == null) {
      if (mounted) {
        setState(() => _fieldError = error ?? 'Could not save that option.');
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
    final String next = writeLedgerOptions(_source, options);
    if (next == _source) {
      return;
    }
    try {
      await widget.documents.write(document, next);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _error = _message(error));
      }
      return;
    }
    _source = next;
  }

  OptionInputs _inputs() => OptionInputs(
    title: _field('title').text,
    documents: <String>[for (final TextEditingController controller in _documents) controller.text],
    operatingCurrencies: <String>[for (final TextEditingController controller in _currencies) controller.text],
    conversionCurrency: _field('conversion').text,
    renderCommas: _renderCommas,
    longStringMaxlines: _field('maxlines').text,
    pluginProcessingMode: _pluginMode,
    insertPythonpath: _insertPythonpath,
    allowPipeSeparator: _allowPipeSeparator,
    allowDeprecatedNoneForTagsAndLinks: _allowDeprecatedNone,
    assets: _field('assets').text,
    liabilities: _field('liabilities').text,
    equity: _field('equity').text,
    income: _field('income').text,
    expenses: _field('expenses').text,
    previousBalances: _field('previousBalances').text,
    previousEarnings: _field('previousEarnings').text,
    previousConversions: _field('previousConversions').text,
    currentEarnings: _field('currentEarnings').text,
    currentConversions: _field('currentConversions').text,
    unrealizedGains: _field('unrealizedGains').text,
    rounding: _field('rounding').text,
    bookingMethod: _booking,
    usePreciseInterpolation: _usePreciseInterpolation,
    inferToleranceFromCost: _inferToleranceFromCost,
    toleranceMultiplier: _field('tolerance').text,
    inferredToleranceMultiplier: _field('inferredMultiplier').text,
    inferredTolerances: <({String key, String value})>[
      for (int index = 0; index < _toleranceKeys.length; index++)
        (key: _toleranceKeys[index].text, value: _toleranceValues[index].text),
    ],
    displayPrecisions: <({String key, String value})>[
      for (int index = 0; index < _precisionKeys.length; index++)
        (key: _precisionKeys[index].text, value: _precisionValues[index].text),
    ],
    baselinePrefixes: _baseline,
  );

  String _message(PlatformException error) {
    final String? message = error.message;
    if (message == null || message.isEmpty) {
      return 'Could not use that file.';
    }
    return message;
  }
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
