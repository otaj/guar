// Account balances grouped by root type in a collapsible tree.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:guar/src/book_ledger.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar_book/guar_book.dart';
import 'package:guar_domain/guar_domain.dart';

class BalancesScreen extends StatefulWidget {
  const BalancesScreen({required this.session, super.key});

  final LedgerSession session;

  @override
  State<BalancesScreen> createState() => _BalancesScreenState();
}

class _BalancesScreenState extends State<BalancesScreen> {
  // Paths start collapsed; expanding a node reveals its direct children.
  final Set<String> _expanded = <String>{};

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
    final LedgerSession session = widget.session;
    final BookedLedger? booked = session.snapshot?.booked;
    if (!session.settled || booked == null) {
      if (session.loading) return const Center(child: CircularProgressIndicator());
      return const SizedBox.shrink();
    }
    final Ledger ledger = booked.ledger;
    if (session.document == null) return const SizedBox.shrink();
    final List<Directive> directives = switch (ledger) {
      LedgerDirectives(:final List<Directive> directives) => directives,
      LedgerErrors() => const <Directive>[],
    };
    final Map<AccountType, List<_AccountNode>> types = _trees(directives, inventoryFromLedger(ledger));
    final List<Widget> rows = _rows(types);
    return CustomScrollView(
      slivers: <Widget>[
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int index) => rows[index],
        ),
      ],
    );
  }

  List<Widget> _rows(Map<AccountType, List<_AccountNode>> types) {
    final List<Widget> rows = <Widget>[];
    for (final AccountType type in _typeOrder) {
      final List<_AccountNode>? roots = types[type];
      if (roots == null || roots.isEmpty) continue;
      rows
        ..add(_TypeHeader(type))
        ..addAll(_flatten(type, roots));
    }
    return rows;
  }

  List<Widget> _flatten(AccountType type, List<_AccountNode> roots) {
    final List<Widget> rows = <Widget>[];
    void visit(_AccountNode node, int depth, String path) {
      final String key = '${type.name}:$path';
      rows.add(
        _AccountTile(
          node: node,
          depth: depth,
          expanded: _expanded.contains(key),
          onToggle: node.hasChildren ? () => _toggle(key) : null,
        ),
      );
      if (_expanded.contains(key)) {
        for (final _AccountNode child in node.sortedChildren) {
          visit(child, depth + 1, '$path:${child.segment}');
        }
      }
    }

    for (final _AccountNode root in roots) {
      visit(root, 0, root.segment);
    }
    return rows;
  }

  void _toggle(String key) {
    setState(() => _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key));
  }
}

const List<AccountType> _typeOrder = <AccountType>[
  AccountType.assets,
  AccountType.expenses,
  AccountType.income,
  AccountType.liabilities,
  AccountType.equity,
];

class _AccountNode {
  _AccountNode(this.segment);

  final String segment;
  final Map<String, _AccountNode> _children = <String, _AccountNode>{};
  Account? account;
  BeanDate? closeDate;
  List<String> declaredCurrencies = const <String>[];
  // Units per currency, with the widest parsed scale for display.
  final Map<String, ({Decimal number, int scale})> balance = <String, ({Decimal number, int scale})>{};

  void addPosition(Amount units) {
    final String currency = units.currency.name;
    final ({Decimal number, int scale}) current = balance[currency] ?? (number: Decimal.zero, scale: 0);
    balance[currency] = (
      number: current.number + units.number,
      scale: current.scale > units.scale ? current.scale : units.scale,
    );
  }

  bool get isVirtual => account == null;

  bool get hasChildren => _children.isNotEmpty;

  List<_AccountNode> get sortedChildren =>
      _children.values.toList()..sort((_AccountNode a, _AccountNode b) => a.segment.compareTo(b.segment));
}

// Builds one tree per root type; virtual nodes aggregate their children's balances.
Map<AccountType, List<_AccountNode>> _trees(List<Directive> directives, LedgerInventory inventory) {
  final Map<AccountType, Map<String, _AccountNode>> roots = <AccountType, Map<String, _AccountNode>>{};

  _AccountNode nodeFor(Account account) {
    final List<String> parts = account.name.split(':');
    Map<String, _AccountNode> level = roots.putIfAbsent(account.type, () => <String, _AccountNode>{});
    _AccountNode node = level.putIfAbsent(parts[1], () => _AccountNode(parts[1]));
    for (int i = 2; i < parts.length; i++) {
      level = node._children;
      node = level.putIfAbsent(parts[i], () => _AccountNode(parts[i]));
    }
    return node;
  }

  for (final Directive directive in directives) {
    switch (directive.body) {
      case OpenBody(:final Account account, :final List<Currency> currencies):
        final _AccountNode node = nodeFor(account);
        node.account ??= account;
        node.declaredCurrencies = <String>[for (final Currency currency in currencies) currency.name];
      case CloseBody(:final Account account):
        final _AccountNode node = nodeFor(account);
        node.account ??= account;
        node.closeDate = directive.date;
      case TransactionBody(:final Transaction value):
        for (final Posting posting in value.postings) {
          nodeFor(posting.account);
        }
      default:
        break;
    }
  }
  for (final AccountInventory entry in inventory.accounts) {
    final _AccountNode node = nodeFor(entry.account);
    for (final Position position in entry.inventory.positions) {
      node.addPosition(position.units);
    }
  }

  void fillVirtual(_AccountNode node) {
    for (final _AccountNode child in node._children.values) {
      fillVirtual(child);
      if (node.isVirtual) {
        for (final MapEntry<String, ({Decimal number, int scale})> entry in child.balance.entries) {
          final ({Decimal number, int scale}) current = node.balance[entry.key] ?? (number: Decimal.zero, scale: 0);
          node.balance[entry.key] = (
            number: current.number + entry.value.number,
            scale: current.scale > entry.value.scale ? current.scale : entry.value.scale,
          );
        }
      }
    }
  }

  for (final Map<String, _AccountNode> level in roots.values) {
    level.values.forEach(fillVirtual);
  }

  return <AccountType, List<_AccountNode>>{
    for (final MapEntry<AccountType, Map<String, _AccountNode>> type in roots.entries)
      type.key: type.value.values.toList()..sort((_AccountNode a, _AccountNode b) => a.segment.compareTo(b.segment)),
  };
}

class _TypeHeader extends StatelessWidget {
  const _TypeHeader(this.type);

  final AccountType type;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: <Widget>[
          Icon(_typeIcon(type), size: 18, color: _typeColor(type, colors)),
          const SizedBox(width: 8),
          Text(
            _typeLabel(type),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: _typeColor(type, colors), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(AccountType type) => switch (type) {
    AccountType.assets => Icons.account_balance_wallet,
    AccountType.expenses => Icons.shopping_cart,
    AccountType.income => Icons.attach_money,
    AccountType.liabilities => Icons.credit_card,
    AccountType.equity => Icons.balance,
  };

  Color _typeColor(AccountType type, ColorScheme colors) => switch (type) {
    AccountType.assets => colors.primary,
    AccountType.expenses => colors.error,
    AccountType.income => Colors.green,
    AccountType.liabilities => Colors.orange,
    AccountType.equity => colors.tertiary,
  };

  String _typeLabel(AccountType type) => '${type.name[0].toUpperCase()}${type.name.substring(1)}';
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.node, required this.depth, required this.expanded, required this.onToggle});

  final _AccountNode node;
  final int depth;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: depth * 24),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        color: node.isVirtual ? colors.surfaceContainerLow : null,
        child: ListTile(
          dense: true,
          leading: node.hasChildren
              ? IconButton(
                  icon: Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 20),
                  onPressed: onToggle,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                )
              : const SizedBox(width: 24),
          title: Text(
            node.segment,
            style: node.isVirtual
                ? Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: colors.onSurface.withAlpha(180))
                : null,
          ),
          trailing: _trailing(context),
          onTap: onToggle,
        ),
      ),
    );
  }

  Widget? _trailing(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (node.closeDate != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(
          'Closed ${_shortDate(node.closeDate!)}',
          style: text.bodySmall?.copyWith(color: colors.error),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (node.balance.isEmpty) {
      final String placeholder = node.isVirtual || node.declaredCurrencies.isEmpty
          ? 'No activity'
          : node.declaredCurrencies.join(', ');
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(
          placeholder,
          style: text.bodySmall?.copyWith(
            color: colors.onSurface.withAlpha(130),
            fontStyle: node.isVirtual ? FontStyle.italic : null,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    final List<MapEntry<String, ({Decimal number, int scale})>> sorted = node.balance.entries.toList()
      ..sort(
        (MapEntry<String, ({Decimal number, int scale})> a, MapEntry<String, ({Decimal number, int scale})> b) =>
            b.value.number.abs().compareTo(a.value.number.abs()),
      );
    final ({Decimal number, int scale}) first = sorted.first.value;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            '${_format(first.number, first.scale)} ${sorted.first.key}',
            style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
          if (sorted.length == 2)
            Text(
              '${_format(sorted[1].value.number, sorted[1].value.scale)} ${sorted[1].key}',
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: colors.onSurface.withAlpha(130), height: 1),
            )
          else if (sorted.length > 2)
            Text(
              '+${sorted.length - 1} more',
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(
                color: colors.onSurface.withAlpha(130),
                fontStyle: FontStyle.italic,
                height: 1,
              ),
            ),
        ],
      ),
    );
  }

  String _format(Decimal number, int scale) {
    String numberText = number.toString();
    if (scale > 0) {
      final int digits = numberText.contains('.') ? numberText.length - numberText.indexOf('.') - 1 : 0;
      numberText = digits == 0 ? '$numberText.${'0' * scale}' : '$numberText${'0' * (scale - digits)}';
    }
    return numberText;
  }

  String _shortDate(BeanDate date) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
