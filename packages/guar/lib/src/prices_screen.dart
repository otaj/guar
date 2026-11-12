// The ledger's price database, listed by date or grouped by currency pair with history graphs.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:guar/l10n/gen/app_localizations.dart';
import 'package:guar/src/amount_text.dart';
import 'package:guar/src/book_ledger.dart';
import 'package:guar/src/date_text.dart';
import 'package:guar/src/ledger_session.dart';
import 'package:guar_domain/guar_domain.dart';

enum _PriceTimeframe { month1, month3, month6, year1, all }

class PricesScreen extends StatefulWidget {
  const PricesScreen({required this.session, super.key});

  final LedgerSession session;

  @override
  State<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends State<PricesScreen> {
  bool _byPair = false;
  _PriceTimeframe _timeframe = _PriceTimeframe.year1;

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
    final TextTheme text = Theme.of(context).textTheme;
    final GuarLocalizations l10n = GuarLocalizations.of(context);
    final LedgerSession session = widget.session;
    final BookedLedger? booked = session.snapshot?.booked;
    if (!session.settled || booked == null) {
      if (session.loading) return const Center(child: CircularProgressIndicator());
      return const SizedBox.shrink();
    }
    final Ledger ledger = booked.ledger;
    final List<Directive> directives = switch (ledger) {
      LedgerDirectives(:final List<Directive> directives) => directives,
      LedgerErrors() => const <Directive>[],
    };
    final bool includeInferred = booked.guar.includeInferredPrices;
    final List<_Quote> quotes = _collectQuotes(directives, includeInferred: includeInferred);
    final Map<CurrencyPair, List<PricePoint>> rates = _rates(directives, includeInferred: includeInferred);
    final List<Widget> rows = _byPair ? _pairRows(rates, l10n) : _quoteRows(quotes);
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
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  key: const Key('viewMode'),
                  segments: <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: false,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(l10n.viewByDate),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: const Icon(Icons.group_work_outlined),
                      label: Text(l10n.viewByPair),
                    ),
                  ],
                  selected: <bool>{_byPair},
                  onSelectionChanged: (Set<bool> next) => setState(() => _byPair = next.first),
                ),
                if (_byPair) ...<Widget>[
                  const SizedBox(height: 8),
                  SegmentedButton<_PriceTimeframe>(
                    key: const Key('timeframe'),
                    segments: <ButtonSegment<_PriceTimeframe>>[
                      for (final _PriceTimeframe frame in _PriceTimeframe.values)
                        ButtonSegment<_PriceTimeframe>(value: frame, label: Text(_frameLabel(frame, l10n))),
                    ],
                    selected: <_PriceTimeframe>{_timeframe},
                    onSelectionChanged: (Set<_PriceTimeframe> next) => setState(() => _timeframe = next.first),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (quotes.isEmpty && rates.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
              child: Text(l10n.noPrices, style: text.bodyLarge),
            ),
          ),
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (BuildContext context, int index) => rows[index],
        ),
      ],
    );
  }

  List<Widget> _pairRows(Map<CurrencyPair, List<PricePoint>> rates, GuarLocalizations l10n) => <Widget>[
    for (final MapEntry<CurrencyPair, List<PricePoint>> entry in rates.entries) _pairCard(entry.key, entry.value, l10n),
  ];

  Widget _pairCard(CurrencyPair pair, List<PricePoint> series, GuarLocalizations l10n) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final PricePoint latest = series.last;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: colors.secondary.withAlpha(15),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.secondary.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${pair.base.name}/${pair.quote.name}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.secondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Text(
                  '${latest.rate} ${pair.quote.name}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              l10n.pricesCount(series.length),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _PairChart(points: _inFrame(series)),
          ],
        ),
      ),
    );
  }

  List<Widget> _quoteRows(List<_Quote> quotes) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Map<BeanDate, List<_Quote>> grouped = <BeanDate, List<_Quote>>{};
    for (final _Quote quote in quotes) {
      grouped.putIfAbsent(quote.date, () => <_Quote>[]).add(quote);
    }
    final List<BeanDate> dates = grouped.keys.toList()..sort((BeanDate a, BeanDate b) => compareBeanDate(b, a));
    return <Widget>[
      for (final BeanDate date in dates) ...<Widget>[
        _DateHeader(date),
        for (final _Quote quote in grouped[date]!) _QuoteTile(quote: quote, color: colors.secondary),
      ],
    ];
  }

  List<PricePoint> _inFrame(List<PricePoint> series) {
    final BeanDate latest = series.last.date;
    final BeanDate? cutoff = switch (_timeframe) {
      _PriceTimeframe.month1 => addDelta(latest, const DateDelta(months: -1)),
      _PriceTimeframe.month3 => addDelta(latest, const DateDelta(months: -3)),
      _PriceTimeframe.month6 => addDelta(latest, const DateDelta(months: -6)),
      _PriceTimeframe.year1 => addDelta(latest, const DateDelta(years: -1)),
      _PriceTimeframe.all => null,
    };
    if (cutoff == null) return series;
    return <PricePoint>[
      for (final PricePoint point in series)
        if (compareBeanDate(point.date, cutoff) >= 0) point,
    ];
  }
}

String _frameLabel(_PriceTimeframe frame, GuarLocalizations l10n) => switch (frame) {
  _PriceTimeframe.month1 => '1M',
  _PriceTimeframe.month3 => '3M',
  _PriceTimeframe.month6 => '6M',
  _PriceTimeframe.year1 => '1Y',
  _PriceTimeframe.all => l10n.timeframeAll,
};

// Quotes newest first; within a day the file order is kept.
class _Quote {
  const _Quote({required this.date, required this.label, required this.meta, required this.inferred});

  final BeanDate date;
  final String label;
  final String meta;
  final bool inferred;
}

List<_Quote> _collectQuotes(List<Directive> directives, {required bool includeInferred}) {
  final List<_Quote> quotes = <_Quote>[];
  final Map<Account, Inventory> balances = <Account, Inventory>{};
  for (final Directive directive in directives) {
    switch (directive.body) {
      case PriceBody(:final Currency currency, :final Amount amount):
        if (currency != amount.currency) {
          quotes.add(
            _Quote(date: directive.date, label: 'price ${currency.name}', meta: amountText(amount), inferred: false),
          );
        }
      case TransactionBody(:final Transaction value):
        if (!includeInferred) break;
        for (final Posting posting in value.postings) {
          final InventoryAdd booking = (balances[posting.account] ?? const Inventory()).addPosition(
            Position(units: posting.units, cost: posting.cost),
          );
          balances[posting.account] = booking.inventory;
          final Amount? quote =
              posting.price ??
              (booking.result != MatchResult.reduced && posting.cost != null
                  ? Amount(number: posting.cost!.number, currency: posting.cost!.currency)
                  : null);
          if (quote == null || quote.currency == posting.units.currency) continue;
          quotes.add(
            _Quote(
              date: directive.date,
              label: 'price ${posting.units.currency.name}',
              meta: '${amountText(quote)} · inferred',
              inferred: true,
            ),
          );
        }
      default:
        break;
    }
  }
  return quotes;
}

Map<CurrencyPair, List<PricePoint>> _rates(List<Directive> directives, {required bool includeInferred}) {
  final List<Directive> priced = includeInferred
      ? directives
      : <Directive>[
          for (final Directive directive in directives)
            if (directive.body is PriceBody) directive,
        ];
  if (priced.isEmpty) return const <CurrencyPair, List<PricePoint>>{};
  final PriceMap built = PriceMap.build(priced);
  return <CurrencyPair, List<PricePoint>>{
    for (final CurrencyPair pair in built.forwardPairs) pair: built.allPrices(pair),
  };
}

class _DateHeader extends StatelessWidget {
  const _DateHeader(this.date);

  final BeanDate date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      formatBeanDate(date, Localizations.localeOf(context).toString()),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.quote, required this.color});

  final _Quote quote;
  final Color color;

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
      leading: Icon(quote.inferred ? Icons.swap_horiz_outlined : Icons.sell_outlined, color: color, size: 20),
      title: Text(
        quote.label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: color, fontFamily: 'monospace'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        quote.meta,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

// Line graph of one pair's rate history; axis labels sit outside the chart.
class _PairChart extends StatelessWidget {
  const _PairChart({required this.points});

  final List<PricePoint> points;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Map<double, PricePoint> byX = <double, PricePoint>{
      for (final PricePoint point in points) _xOf(point): point,
    };
    final List<FlSpot> spots = <FlSpot>[
      for (final PricePoint point in points) FlSpot(_xOf(point), point.rate.toDouble()),
    ];
    final double minX = spots.first.x;
    final double maxX = spots.last.x;
    final List<PricePoint> sorted = <PricePoint>[...points]
      ..sort((PricePoint a, PricePoint b) => a.rate.compareTo(b.rate));
    final double minY = sorted.first.rate.toDouble();
    final double maxY = sorted.last.rate.toDouble();
    final double spread = maxY - minY;
    final double pad = spread == 0 ? (maxY == 0 ? 1 : maxY.abs() * 0.1 + 0.01) : spread * 0.08;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 140,
          width: double.infinity,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY - pad,
              maxY: maxY + pad,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (FlSpot spot) => colors.surfaceContainerHighest,
                  getTooltipItems: (List<LineBarSpot> spots) => <LineTooltipItem?>[
                    for (final LineBarSpot spot in spots)
                      LineTooltipItem(
                        '${_dateOf(spot.x)}\n${byX[spot.x]!.rate}',
                        TextStyle(color: colors.onSurface, fontSize: 11, fontFamily: 'monospace'),
                      ),
                  ],
                ),
              ),
              lineBarsData: <LineChartBarData>[
                LineChartBarData(
                  spots: spots,
                  color: colors.secondary,
                  dotData: FlDotData(
                    getDotPainter: (FlSpot spot, double _, LineChartBarData _, int _) =>
                        FlDotCirclePainter(radius: 2, color: colors.secondary, strokeColor: colors.secondary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(_dateOf(minX), style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ),
            Text(_dateOf(maxX), style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  double _xOf(PricePoint point) =>
      DateTime.utc(point.date.year, point.date.month, point.date.day).millisecondsSinceEpoch / 86400000;

  String _dateOf(double epochDays) {
    final DateTime native = DateTime.fromMillisecondsSinceEpoch((epochDays * 86400000).round(), isUtc: true);
    return '${native.year.toString().padLeft(4, '0')}-'
        '${native.month.toString().padLeft(2, '0')}-'
        '${native.day.toString().padLeft(2, '0')}';
  }
}
