// Lists every booked directive in the open ledger.

import 'package:flutter/material.dart';
import 'package:guar/src/book_ledger.dart';
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
  BookedLedger? _booked;
  String? _bookedSource;
  String? _bookedName;

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
    if (!session.settled) return const SizedBox.shrink();
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

    final BookedLedger booked = _bookedFor(session);
    final Ledger ledger = booked.ledger;
    final List<Directive> directives = switch (ledger) {
      LedgerDirectives(:final List<Directive> directives) => directives,
      LedgerErrors() => const <Directive>[],
    };
    final List<Directive> visible = <Directive>[
      for (final Directive directive in directives)
        if (!_hidden(directive, booked)) directive,
    ];
    final List<ProcessingError> errors = switch (ledger) {
      LedgerDirectives(:final List<ProcessingError> errors) => errors,
      LedgerErrors(:final List<ProcessingError> errors) => errors,
    };
    final String? emptyMessage = _emptyMessage(
      visible: visible,
      directives: directives,
      errors: errors,
      sessionError: sessionError,
    );
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(ledger.options.title, style: text.titleMedium),
                if (sessionError != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(sessionError, style: text.bodyMedium?.copyWith(color: colors.error)),
                ],
                for (final String warning in booked.optionWarnings) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(warning, style: text.bodyMedium?.copyWith(color: colors.error)),
                ],
                for (final ProcessingError error in errors) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(error.message, style: text.bodyMedium?.copyWith(color: colors.error)),
                ],
                if (session.busy) ...<Widget>[const SizedBox(height: 12), const LinearProgressIndicator()],
              ],
            ),
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
          itemCount: visible.length,
          itemBuilder: (BuildContext context, int index) => _DirectiveChip(directive: visible[index]),
        ),
      ],
    );
  }

  BookedLedger _bookedFor(LedgerSession session) {
    final String source = session.source;
    final String name = session.document?.displayName ?? '';
    final BookedLedger? cached = _booked;
    if (cached != null && _bookedSource == source && _bookedName == name) return cached;
    _bookedSource = source;
    _bookedName = name;
    final BookedLedger booked = bookLedger(source, filename: name);
    _booked = booked;
    return booked;
  }
}

bool _hidden(Directive directive, BookedLedger booked) =>
    booked.guar.hidden.contains(directiveHideToken(directive.body)) ||
    (booked.guar.hidden.contains(GuarHide.generated.token) && booked.isGenerated(directive));

String? _emptyMessage({
  required List<Directive> visible,
  required List<Directive> directives,
  required List<ProcessingError> errors,
  required String? sessionError,
}) {
  if (visible.isNotEmpty) return null;
  if (directives.isNotEmpty) return 'Every directive is hidden.';
  if (errors.isEmpty && sessionError == null) return 'This ledger has no directives.';
  return null;
}

class _DirectiveChip extends StatelessWidget {
  const _DirectiveChip({required this.directive});

  final Directive directive;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final DirectiveBody body = directive.body;
    final String kind = _kind(body);
    final String detail = _detail(body);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 4),
      child: Chip(
        avatar: Icon(_icon(body)),
        labelPadding: EdgeInsets.zero,
        labelStyle: text.bodyLarge?.copyWith(color: colors.onSurface),
        label: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(detail.isEmpty ? kind : detail),
                Text('${directive.date} · $kind', style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _icon(DirectiveBody body) => switch (body) {
  TransactionBody() => Icons.receipt_long_outlined,
  PriceBody() => Icons.sell_outlined,
  BalanceBody() => Icons.account_balance_outlined,
  OpenBody() => Icons.lock_open_outlined,
  CloseBody() => Icons.lock_outlined,
  CommodityBody() => Icons.paid_outlined,
  PadBody() => Icons.align_vertical_center_outlined,
  DocumentBody() => Icons.description_outlined,
  NoteBody() => Icons.sticky_note_2_outlined,
  EventBody() => Icons.event_outlined,
  QueryBody() => Icons.manage_search_outlined,
  CustomBody() => Icons.category_outlined,
  BudgetBody() => Icons.savings_outlined,
  BudgetOffBody() => Icons.money_off_outlined,
};

String _kind(DirectiveBody body) => switch (body) {
  TransactionBody() => 'Transaction',
  PriceBody() => 'Price',
  BalanceBody() => 'Balance',
  OpenBody() => 'Open',
  CloseBody() => 'Close',
  CommodityBody() => 'Commodity',
  PadBody() => 'Pad',
  DocumentBody() => 'Document',
  NoteBody() => 'Note',
  EventBody() => 'Event',
  QueryBody() => 'Query',
  CustomBody() => 'Custom',
  BudgetBody() => 'Budget',
  BudgetOffBody() => 'Budget off',
};

String _detail(DirectiveBody body) => switch (body) {
  TransactionBody(:final Transaction value) => _transaction(value),
  PriceBody(:final Currency currency, :final Amount amount) => '${currency.name} $amount',
  BalanceBody(:final Account account, :final Amount amount) => '${account.name} $amount',
  OpenBody(:final Account account) => account.name,
  CloseBody(:final Account account) => account.name,
  CommodityBody(:final Currency currency) => currency.name,
  PadBody(:final Account account, :final Account sourceAccount) => '${account.name} ${sourceAccount.name}',
  DocumentBody(:final String filename) => filename,
  NoteBody(:final Account account, :final String comment) => '${account.name} $comment',
  EventBody(:final String name, :final String description) => '$name $description',
  QueryBody(:final String name) => name,
  CustomBody(:final String type) => type,
  BudgetBody(:final Account account, :final BudgetInterval interval, :final Amount amount) =>
    '${account.name} ${_interval(interval)} $amount',
  BudgetOffBody(:final Account account, :final Currency? currency) =>
    currency == null ? account.name : '${account.name} ${currency.name}',
};

String _transaction(Transaction value) {
  final String text = <String>[
    if (value.payee != null && value.payee!.isNotEmpty) value.payee!,
    if (value.narration.isNotEmpty) value.narration,
  ].join(' — ');
  final String flag = _flag(value.flag);
  if (text.isEmpty) return flag;
  return '$flag $text';
}

String _flag(Flag flag) => switch (flag) {
  SpecialFlagValue(:final SpecialFlag value) => switch (value) {
    SpecialFlag.asterisk => '*',
    SpecialFlag.exclamation => '!',
    SpecialFlag.hash => '#',
    SpecialFlag.ampersand => '&',
    SpecialFlag.question => '?',
    SpecialFlag.percent => '%',
  },
  LetterFlag(:final String value) => value,
};

String _interval(BudgetInterval interval) => switch (interval) {
  BudgetInterval.daily => 'daily',
  BudgetInterval.weekly => 'weekly',
  BudgetInterval.monthly => 'monthly',
  BudgetInterval.quarterly => 'quarterly',
  BudgetInterval.yearly => 'yearly',
};
