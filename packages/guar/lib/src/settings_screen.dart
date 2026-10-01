// Ledger-specific settings: exposes Beancount options, prefilled with defaults.
import 'package:flutter/material.dart';
import 'package:guar/src/ledger_documents.dart';
import 'package:guar_domain/guar_domain.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.documents, required this.options, super.key});

  final LedgerDocument documents;
  final LedgerOptions options;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _title;
  late final TextEditingController _operatingCurrency;
  late final TextEditingController _conversionCurrency;
  late final TextEditingController _renderCommas;
  late final TextEditingController _bookingMethod;
  late final TextEditingController _pluginProcessingMode;
  late final TextEditingController _longStringMaxlines;
  late final TextEditingController _inferToleranceFromCost;
  late final TextEditingController _toleranceMultiplier;
  late final TextEditingController _usePreciseInterpolation;
  late final TextEditingController _nameAssets;
  late final TextEditingController _nameLiabilities;
  late final TextEditingController _nameEquity;
  late final TextEditingController _nameIncome;
  late final TextEditingController _nameExpenses;
  late final TextEditingController _accountPreviousBalances;
  late final TextEditingController _accountPreviousEarnings;
  late final TextEditingController _accountPreviousConversions;
  late final TextEditingController _accountCurrentEarnings;
  late final TextEditingController _accountCurrentConversions;
  late final TextEditingController _accountRounding;
  late final TextEditingController _accountUnrealizedGains;

  @override
  void initState() {
    super.initState();
    final LedgerOptions o = widget.options;
    _title = TextEditingController(text: o.title);
    _operatingCurrency = TextEditingController(text: o.operatingCurrency.map((Currency c) => c.name).join(', '));
    _conversionCurrency = TextEditingController(text: o.conversionCurrency.name);
    _renderCommas = TextEditingController(text: o.renderCommas.toString());
    _bookingMethod = TextEditingController(text: _bookingMethodName(o.bookingMethod));
    _pluginProcessingMode = TextEditingController(text: o.pluginProcessingMode.name.toUpperCase());
    _longStringMaxlines = TextEditingController(text: o.longStringMaxlines.toString());
    _inferToleranceFromCost = TextEditingController(text: o.inferToleranceFromCost.toString());
    _toleranceMultiplier = TextEditingController(text: o.toleranceMultiplier.value.toDouble().toString());
    _usePreciseInterpolation = TextEditingController(text: o.usePreciseInterpolation.toString());
    _nameAssets = TextEditingController(text: o.accountPrefixes.assets);
    _nameLiabilities = TextEditingController(text: o.accountPrefixes.liabilities);
    _nameEquity = TextEditingController(text: o.accountPrefixes.equity);
    _nameIncome = TextEditingController(text: o.accountPrefixes.income);
    _nameExpenses = TextEditingController(text: o.accountPrefixes.expenses);
    _accountPreviousBalances = TextEditingController(text: o.accountPreviousBalances.name);
    _accountPreviousEarnings = TextEditingController(text: o.accountPreviousEarnings.name);
    _accountPreviousConversions = TextEditingController(text: o.accountPreviousConversions.name);
    _accountCurrentEarnings = TextEditingController(text: o.accountCurrentEarnings.name);
    _accountCurrentConversions = TextEditingController(text: o.accountCurrentConversions.name);
    _accountRounding = TextEditingController(text: o.accountRounding?.name ?? '');
    _accountUnrealizedGains = TextEditingController(text: o.accountUnrealizedGains.name);
  }

  @override
  void dispose() {
    _title.dispose();
    _operatingCurrency.dispose();
    _conversionCurrency.dispose();
    _renderCommas.dispose();
    _bookingMethod.dispose();
    _pluginProcessingMode.dispose();
    _longStringMaxlines.dispose();
    _inferToleranceFromCost.dispose();
    _toleranceMultiplier.dispose();
    _usePreciseInterpolation.dispose();
    _nameAssets.dispose();
    _nameLiabilities.dispose();
    _nameEquity.dispose();
    _nameIncome.dispose();
    _nameExpenses.dispose();
    _accountPreviousBalances.dispose();
    _accountPreviousEarnings.dispose();
    _accountPreviousConversions.dispose();
    _accountCurrentEarnings.dispose();
    _accountCurrentConversions.dispose();
    _accountRounding.dispose();
    _accountUnrealizedGains.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ledger settings')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _section('General'),
                _textField('Title', _title),
                _textField('Operating currency', _operatingCurrency, hint: 'e.g. USD, EUR'),
                _textField('Conversion currency', _conversionCurrency, hint: 'e.g. USD'),
                const SizedBox(height: 16),
                _section('Display'),
                _boolField('Render commas', _renderCommas),
                _intField('Long string maxlines', _longStringMaxlines),
                const SizedBox(height: 16),
                _section('Booking'),
                _boolField('Infer tolerance from cost', _inferToleranceFromCost),
                _textField('Tolerance multiplier', _toleranceMultiplier, hint: 'e.g. 0.005'),
                _dropdownField('Booking method', _bookingMethod, _bookingMethods),
                const SizedBox(height: 16),
                _section('Processing'),
                _dropdownField('Plugin processing mode', _pluginProcessingMode, <String>['DEFAULT', 'RAW']),
                _boolField('Use precise interpolation', _usePreciseInterpolation),
                const SizedBox(height: 16),
                _section('Account prefixes'),
                _textField('Assets', _nameAssets, hint: 'e.g. Assets'),
                _textField('Liabilities', _nameLiabilities, hint: 'e.g. Liabilities'),
                _textField('Equity', _nameEquity, hint: 'e.g. Equity'),
                _textField('Income', _nameIncome, hint: 'e.g. Income'),
                _textField('Expenses', _nameExpenses, hint: 'e.g. Expenses'),
                const SizedBox(height: 16),
                _section('Accounts'),
                _textField('Previous balances', _accountPreviousBalances, hint: 'e.g. Equity:Opening-Balances'),
                _textField('Previous earnings', _accountPreviousEarnings, hint: 'e.g. Equity:Opening-Balances'),
                _textField('Previous conversions', _accountPreviousConversions, hint: 'e.g. Equity:Conversions'),
                _textField('Current earnings', _accountCurrentEarnings, hint: 'e.g. Income:Current'),
                _textField('Current conversions', _accountCurrentConversions, hint: 'e.g. Equity:Conversions'),
                _textField('Rounding', _accountRounding, hint: 'e.g. Equity:Rounding'),
                _textField('Unrealized gains', _accountUnrealizedGains, hint: 'e.g. Income:Unrealized-Gains'),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _textField(String label, TextEditingController controller, {String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
    ),
  );

  Widget _boolField(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Switch(
          value: controller.text == 'true',
          onChanged: (bool value) => setState(() => controller.text = value.toString()),
        ),
      ],
    ),
  );

  Widget _intField(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    ),
  );

  Widget _dropdownField(String label, TextEditingController controller, List<String> items) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(controller.text) ? controller.text : null,
          isExpanded: true,
          items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
          onChanged: (String? value) {
            if (value != null) {
              setState(() => controller.text = value);
            }
          },
        ),
      ),
    ),
  );

  static const List<String> _bookingMethods = <String>[
    'STRICT',
    'STRICT_WITH_SIZE',
    'NONE',
    'AVERAGE',
    'FIFO',
    'LIFO',
    'HIFO',
  ];

  static String _bookingMethodName(BookingMethod method) => switch (method) {
    BookingMethod.strict => 'STRICT',
    BookingMethod.strictWithSize => 'STRICT_WITH_SIZE',
    BookingMethod.none => 'NONE',
    BookingMethod.average => 'AVERAGE',
    BookingMethod.fifo => 'FIFO',
    BookingMethod.lifo => 'LIFO',
    BookingMethod.hifo => 'HIFO',
  };

  void _save() {
    final LedgerOptions defaults = LedgerOptions();
    final List<String> lines = <String>[];

    final String title = _title.text.trim();
    if (title.isNotEmpty && title != defaults.title) {
      lines.add('option "title" "$title"');
    }

    final String operatingCurrency = _operatingCurrency.text.trim();
    if (operatingCurrency.isNotEmpty) {
      for (final String currency in operatingCurrency.split(',')) {
        final String trimmed = currency.trim();
        if (trimmed.isNotEmpty) {
          lines.add('option "operating_currency" "$trimmed"');
        }
      }
    }

    final String conversionCurrency = _conversionCurrency.text.trim();
    if (conversionCurrency.isNotEmpty && conversionCurrency != defaults.conversionCurrency.name) {
      lines.add('option "conversion_currency" "$conversionCurrency"');
    }

    final String renderCommas = _renderCommas.text.trim();
    if (renderCommas == 'true' && renderCommas != defaults.renderCommas.toString()) {
      lines.add('option "render_commas" "true"');
    }

    final String bookingMethod = _bookingMethod.text.trim();
    if (bookingMethod.isNotEmpty && bookingMethod != _bookingMethodName(defaults.bookingMethod)) {
      lines.add('option "booking_method" "$bookingMethod"');
    }

    final String pluginMode = _pluginProcessingMode.text.trim();
    if (pluginMode.isNotEmpty && pluginMode != defaults.pluginProcessingMode.name.toUpperCase()) {
      lines.add('option "plugin_processing_mode" "$pluginMode"');
    }

    final String longStringMaxlines = _longStringMaxlines.text.trim();
    if (longStringMaxlines.isNotEmpty && longStringMaxlines != defaults.longStringMaxlines.toString()) {
      lines.add('option "long_string_maxlines" "$longStringMaxlines"');
    }

    final String inferTolerance = _inferToleranceFromCost.text.trim();
    if (inferTolerance == 'true' && inferTolerance != defaults.inferToleranceFromCost.toString()) {
      lines.add('option "infer_tolerance_from_cost" "true"');
    }

    final String toleranceMultiplier = _toleranceMultiplier.text.trim();
    if (toleranceMultiplier.isNotEmpty &&
        toleranceMultiplier != defaults.toleranceMultiplier.value.toDouble().toString()) {
      lines.add('option "tolerance_multiplier" "$toleranceMultiplier"');
    }

    final String usePreciseInterpolation = _usePreciseInterpolation.text.trim();
    if (usePreciseInterpolation == 'true' && usePreciseInterpolation != defaults.usePreciseInterpolation.toString()) {
      lines.add('option "use_precise_interpolation" "true"');
    }

    final String nameAssets = _nameAssets.text.trim();
    if (nameAssets.isNotEmpty && nameAssets != defaults.accountPrefixes.assets) {
      lines.add('option "name_assets" "$nameAssets"');
    }

    final String nameLiabilities = _nameLiabilities.text.trim();
    if (nameLiabilities.isNotEmpty && nameLiabilities != defaults.accountPrefixes.liabilities) {
      lines.add('option "name_liabilities" "$nameLiabilities"');
    }

    final String nameEquity = _nameEquity.text.trim();
    if (nameEquity.isNotEmpty && nameEquity != defaults.accountPrefixes.equity) {
      lines.add('option "name_equity" "$nameEquity"');
    }

    final String nameIncome = _nameIncome.text.trim();
    if (nameIncome.isNotEmpty && nameIncome != defaults.accountPrefixes.income) {
      lines.add('option "name_income" "$nameIncome"');
    }

    final String nameExpenses = _nameExpenses.text.trim();
    if (nameExpenses.isNotEmpty && nameExpenses != defaults.accountPrefixes.expenses) {
      lines.add('option "name_expenses" "$nameExpenses"');
    }

    final String accountPreviousBalances = _accountPreviousBalances.text.trim();
    if (accountPreviousBalances.isNotEmpty && accountPreviousBalances != defaults.accountPreviousBalances.name) {
      lines.add('option "account_previous_balances" "$accountPreviousBalances"');
    }

    final String accountPreviousEarnings = _accountPreviousEarnings.text.trim();
    if (accountPreviousEarnings.isNotEmpty && accountPreviousEarnings != defaults.accountPreviousEarnings.name) {
      lines.add('option "account_previous_earnings" "$accountPreviousEarnings"');
    }

    final String accountPreviousConversions = _accountPreviousConversions.text.trim();
    if (accountPreviousConversions.isNotEmpty &&
        accountPreviousConversions != defaults.accountPreviousConversions.name) {
      lines.add('option "account_previous_conversions" "$accountPreviousConversions"');
    }

    final String accountCurrentEarnings = _accountCurrentEarnings.text.trim();
    if (accountCurrentEarnings.isNotEmpty && accountCurrentEarnings != defaults.accountCurrentEarnings.name) {
      lines.add('option "account_current_earnings" "$accountCurrentEarnings"');
    }

    final String accountCurrentConversions = _accountCurrentConversions.text.trim();
    if (accountCurrentConversions.isNotEmpty && accountCurrentConversions != defaults.accountCurrentConversions.name) {
      lines.add('option "account_current_conversions" "$accountCurrentConversions"');
    }

    final String accountRounding = _accountRounding.text.trim();
    if (accountRounding.isNotEmpty && accountRounding != (defaults.accountRounding?.name ?? '')) {
      lines.add('option "account_rounding" "$accountRounding"');
    }

    final String accountUnrealizedGains = _accountUnrealizedGains.text.trim();
    if (accountUnrealizedGains.isNotEmpty && accountUnrealizedGains != defaults.accountUnrealizedGains.name) {
      lines.add('option "account_unrealized_gains" "$accountUnrealizedGains"');
    }

    if (lines.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    // TODO(guar): write lines to the ledger file
    Navigator.of(context).pop();
  }
}
