// Lists every booked directive in the open ledger, grouped by date.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:guar/src/book_ledger.dart';
import 'package:guar/src/date_text.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';

class DirectivesScreen extends StatefulWidget {
  const DirectivesScreen({required this.session, super.key});

  final LedgerSession session;

  @override
  State<DirectivesScreen> createState() => _DirectivesScreenState();
}

class _DirectivesScreenState extends State<DirectivesScreen> {
  bool _warningsExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final LedgerSession session = widget.session;
    final BookedLedger? booked = session.snapshot?.booked;
    if (!session.settled || booked == null) {
      if (session.loading) return const Center(child: CircularProgressIndicator());
      return const SizedBox.shrink();
    }
    final String? sessionError = session.error;
    if (session.document == null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          sessionError ?? 'No ledger is selected. Choose one in Settings.',
          style: text.bodyLarge?.copyWith(color: sessionError == null ? colors.onSurfaceVariant : colors.error),
        ),
      );
    }

    final Ledger ledger = booked.ledger;
    final List<Directive> directives = switch (ledger) {
      LedgerDirectives(:final List<Directive> directives) => directives,
      LedgerErrors() => const <Directive>[],
    };
    final List<Directive> visible = <Directive>[
      for (final Directive directive in directives)
        if (!_hidden(directive, booked)) directive,
    ];
    final List<String> messages = <String>[
      ?sessionError,
      ...booked.optionWarnings,
      for (final ProcessingError error in _errors(ledger)) error.message,
    ];
    final String? emptyMessage = _emptyMessage(
      visible: visible,
      directives: directives,
      messages: messages,
    );
    final List<Widget> rows = _rows(visible);
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(ledger.options.title, style: text.titleMedium),
                if (session.busy || session.loading) ...<Widget>[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
        if (messages.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
              child: _WarningBanner(messages: messages, expanded: _warningsExpanded, onToggle: _toggleWarnings),
            ),
          ),
        if (emptyMessage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
              child: Text(emptyMessage, style: text.bodyLarge),
            ),
          ),
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int index) => rows[index],
        ),
      ],
    );
  }

  void _toggleWarnings() {
    setState(() => _warningsExpanded = !_warningsExpanded);
  }

  List<ProcessingError> _errors(Ledger ledger) => switch (ledger) {
    LedgerDirectives(:final List<ProcessingError> errors) => errors,
    LedgerErrors(:final List<ProcessingError> errors) => errors,
  };

  // Date groups newest first; directives within a day keep file order.
  List<Widget> _rows(List<Directive> visible) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Map<BeanDate, List<Directive>> grouped = <BeanDate, List<Directive>>{};
    for (final Directive directive in visible) {
      grouped.putIfAbsent(directive.date, () => <Directive>[]).add(directive);
    }
    final List<BeanDate> dates = grouped.keys.toList()..sort((BeanDate a, BeanDate b) => compareBeanDate(b, a));
    return <Widget>[
      for (final BeanDate date in dates) ...<Widget>[
        _DateHeader(date),
        for (final Directive directive in grouped[date]!) _tileRow(directive, colors),
      ],
    ];
  }

  Widget _tileRow(Directive directive, ColorScheme colors) => switch (directive.body) {
    TransactionBody(:final Transaction value) => _TransactionTile(value),
    _ => _DirectiveTile(
      icon: _icon(directive.body),
      color: _color(directive.body, colors),
      label: _label(directive.body),
      meta: _meta(directive.body),
    ),
  };
}

bool _hidden(Directive directive, BookedLedger booked) =>
    booked.guar.hidden.contains(directiveHideToken(directive.body)) ||
    (booked.guar.hidden.contains(GuarHide.generated.token) && booked.isGenerated(directive));

String? _emptyMessage({
  required List<Directive> visible,
  required List<Directive> directives,
  required List<String> messages,
}) {
  if (visible.isNotEmpty) return null;
  if (directives.isNotEmpty) return 'Every directive is hidden.';
  if (messages.isEmpty) return 'This ledger has no directives.';
  return null;
}

class _DateHeader extends StatelessWidget {
  const _DateHeader(this.date);

  final BeanDate date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      formatBeanDate(date),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.value);

  final Transaction value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<Posting> debits = <Posting>[
      for (final Posting posting in value.postings)
        if (posting.units.number > Decimal.zero) posting,
    ];
    final List<Posting> credits = <Posting>[
      for (final Posting posting in value.postings)
        if (posting.units.number < Decimal.zero) posting,
    ];
    final Amount? displayAmount = debits.isEmpty ? null : debits.first.units;
    String subtitle;
    if (value.payee != null && value.payee!.isNotEmpty) {
      subtitle = value.payee!;
    } else if (credits.isNotEmpty && debits.isNotEmpty) {
      subtitle = '${_leaves(credits)} → ${_leaves(debits)}';
    } else if (value.postings.isNotEmpty) {
      subtitle = _leaf(value.postings.first.account.name);
    } else {
      subtitle = '';
    }
    if (value.postings.length > 2) {
      subtitle += ' (${value.postings.length} postings)';
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.secondaryContainer,
          child: Icon(Icons.receipt_long_outlined, color: colors.onSecondaryContainer, size: 20),
        ),
        title: Text(
          value.narration.isEmpty ? '(no description)' : value.narration,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontStyle: value.narration.isEmpty ? FontStyle.italic : FontStyle.normal),
        ),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: displayAmount == null
            ? null
            : Text(
                _amountText(displayAmount),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  String _leaves(List<Posting> postings) {
    final Set<String> leaves = <String>{for (final Posting posting in postings) _leaf(posting.account.name)};
    return leaves.join(', ');
  }

  String _leaf(String name) => name.split(':').last;
}

// Keeps the parsed number's digits, e.g. 1.10 instead of Decimal's 1.1.
String _amountText(Amount amount) {
  final String number = amount.number.toString();
  final int digits = number.contains('.') ? number.length - number.indexOf('.') - 1 : 0;
  final String padded = amount.scale > digits ? '$number${'0' * (amount.scale - digits)}' : number;
  return '$padded ${amount.currency.name}';
}

class _DirectiveTile extends StatelessWidget {
  const _DirectiveTile({required this.icon, required this.color, required this.label, this.meta});

  final IconData icon;
  final Color color;
  final String label;
  final String? meta;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    color: color.withAlpha(15),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: color.withAlpha(40)),
    ),
    child: ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: color, fontFamily: 'monospace'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: meta == null || meta!.isEmpty
          ? null
          : Text(
              meta!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    ),
  );
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.messages, required this.expanded, required this.onToggle});

  final List<String> messages;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.tertiaryContainer.withAlpha(120),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, size: 18, color: colors.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${messages.length} ${messages.length == 1 ? 'warning' : 'warnings'}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.tertiary),
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: colors.tertiary),
                ],
              ),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final String message in messages)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            message,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _icon(DirectiveBody body) => switch (body) {
  TransactionBody() => Icons.receipt_long_outlined,
  OpenBody() => Icons.lock_open_outlined,
  CloseBody() => Icons.lock_outlined,
  BalanceBody() => Icons.account_balance_outlined,
  PadBody() => Icons.align_vertical_center_outlined,
  PriceBody() => Icons.sell_outlined,
  CommodityBody() => Icons.paid_outlined,
  NoteBody() => Icons.sticky_note_2_outlined,
  DocumentBody() => Icons.description_outlined,
  EventBody() => Icons.event_outlined,
  QueryBody() => Icons.manage_search_outlined,
  CustomBody() => Icons.category_outlined,
  BudgetBody() => Icons.savings_outlined,
  BudgetOffBody() => Icons.money_off_outlined,
};

Color _color(DirectiveBody body, ColorScheme colors) => switch (body) {
  TransactionBody() => colors.primary,
  OpenBody() => Colors.green,
  CloseBody() => colors.error,
  BalanceBody() => colors.tertiary,
  PadBody() => colors.secondary,
  PriceBody() => colors.secondary,
  CommodityBody() => colors.onSurface.withAlpha(180),
  NoteBody() => colors.onSurface.withAlpha(160),
  DocumentBody() => colors.secondary,
  EventBody() => colors.tertiary,
  QueryBody() => colors.primary,
  CustomBody() => colors.onSurface.withAlpha(180),
  BudgetBody() => colors.tertiary,
  BudgetOffBody() => colors.tertiary,
};

String _label(DirectiveBody body) => switch (body) {
  TransactionBody() => '',
  OpenBody(:final Account account) => 'open ${account.name}',
  CloseBody(:final Account account) => 'close ${account.name}',
  BalanceBody(:final Account account) => 'balance ${account.name}',
  PadBody(:final Account account) => 'pad ${account.name}',
  PriceBody(:final Currency currency) => 'price ${currency.name}',
  CommodityBody(:final Currency currency) => 'commodity ${currency.name}',
  NoteBody(:final Account account) => 'note ${account.name}',
  DocumentBody(:final Account account) => 'document ${account.name}',
  EventBody(:final String name) => 'event "$name"',
  QueryBody(:final String name) => 'query $name',
  CustomBody(:final String type) => 'custom $type',
  BudgetBody(:final Account account) => 'budget ${account.name}',
  BudgetOffBody(:final Account account) => 'budget off ${account.name}',
};

String? _meta(DirectiveBody body) => switch (body) {
  TransactionBody() => null,
  OpenBody(:final List<Currency> currencies) =>
    currencies.isEmpty ? null : currencies.map((Currency c) => c.name).join(', '),
  BalanceBody(:final Amount amount, :final Decimal? tolerance) =>
    '${_amountText(amount)}${tolerance == null ? '' : ' ~ $tolerance'}',
  CloseBody() => null,
  PadBody(:final Account sourceAccount) => 'from ${sourceAccount.name}',
  PriceBody(:final Amount amount) => _amountText(amount),
  CommodityBody() => null,
  NoteBody(:final String comment) => comment,
  DocumentBody(:final String filename) => filename,
  EventBody(:final String description) => description,
  QueryBody() => null,
  CustomBody(:final List<CustomValue> values) => values.isEmpty ? null : values.map(_customValue).join(' '),
  BudgetBody(:final BudgetInterval interval, :final Amount amount) => '${_interval(interval)} ${_amountText(amount)}',
  BudgetOffBody(:final Currency? currency) => currency?.name,
};

String _customValue(CustomValue value) => switch (value) {
  CustomText(:final String value) => value,
  CustomAccount(:final Account value) => value.name,
  CustomDate(:final BeanDate value) => '$value',
  CustomBoolean(:final bool value) => '$value',
  CustomNumber(:final Decimal value) => '$value',
  CustomAmount(:final Amount value) => '$value',
  CustomCurrency(:final Currency value) => value.name,
};

String _interval(BudgetInterval interval) => switch (interval) {
  BudgetInterval.daily => 'daily',
  BudgetInterval.weekly => 'weekly',
  BudgetInterval.monthly => 'monthly',
  BudgetInterval.quarterly => 'quarterly',
  BudgetInterval.yearly => 'yearly',
};
