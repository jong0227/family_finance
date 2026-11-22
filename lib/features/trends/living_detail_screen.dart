import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import '../../domain/finance_models.dart';

/// 생활비 항목 하나의 세부 — 12개월 추이(계획선) · 이번 달 구성 · 많이 쓴 곳 · 거래.
class LivingDetailScreen extends ConsumerStatefulWidget {
  const LivingDetailScreen({super.key, required this.group});
  final String group;

  @override
  ConsumerState<LivingDetailScreen> createState() => _LivingDetailScreenState();
}

class _LivingDetailScreenState extends ConsumerState<LivingDetailScreen> {
  /// "무엇에 썼나"에서 고른 구성(포커스). null 이면 전체.
  String? _focus;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final txs = ref.watch(livingTxProvider(group));
    final months = ref.watch(monthsProvider).value ?? const <MonthAgg>[];
    final plan = ref.watch(planProvider).value?.livingPlan[group] ?? 0;
    final current = ref.watch(currentMonthProvider);
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(livingLabels[group] ?? group)),
      body: txs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final regular = all.where((x) => !x.oneOff).toList();
          final monthList = [for (final m in months) m.month];
          final last12 = monthList.length > 12 ? monthList.sublist(monthList.length - 12) : monthList;
          final byMonth = <String, int>{for (final m in last12) m: 0};
          for (final x in regular) {
            if (byMonth.containsKey(x.month)) byMonth[x.month] = byMonth[x.month]! - x.amount;
          }
          final month = current ?? (last12.isEmpty ? '' : last12.last);
          final inMonth = regular.where((x) => x.month == month).toList();
          final total = inMonth.fold<int>(0, (a, x) => a - x.amount);
          final full = [for (final m in last12) if (!(months.firstWhere((x) => x.month == m).partial)) byMonth[m]!];
          final last6 = full.length > 6 ? full.sublist(full.length - 6) : full;
          final avg6 = last6.isEmpty ? 0 : last6.reduce((a, b) => a + b) ~/ last6.length;

          final parts = <String, int>{};
          final merchants = <String, int>{};
          for (final x in inMonth) {
            parts[x.livingPart] = (parts[x.livingPart] ?? 0) - x.amount;
            merchants[x.merchantKey] = (merchants[x.merchantKey] ?? 0) - x.amount;
          }
          final partList = parts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final focus = parts.containsKey(_focus) ? _focus : null;
          final shown = focus == null ? inMonth : inMonth.where((x) => x.livingPart == focus).toList();
          final shownTotal = shown.fold<int>(0, (a, x) => a - x.amount);
          merchants.clear();
          for (final x in shown) {
            merchants[x.merchantKey] = (merchants[x.merchantKey] ?? 0) - x.amount;
          }
          final topMerchants = merchants.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final maxY = [...byMonth.values, plan].fold<int>(0, (a, b) => a > b ? a : b) / 10000 * 1.15;

          return ListView(padding: const EdgeInsets.only(bottom: AppGap.xl), children: [
            MonthSwitcher(month: month, months: monthList, onChanged: ref.read(selectedMonthProvider.notifier).set),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
              child: Row(children: [
                KpiTile(
                  label: '이 달',
                  value: man(total),
                  sub: plan > 0 ? '계획 ${man(plan)}' : null,
                  valueColor: plan > 0 && total > plan * 1.05 ? p.over : null,
                ),
                const SizedBox(width: AppGap.sm),
                KpiTile(label: '최근 6개월 평균', value: man(avg6), sub: plan > 0 ? '계획의 ${(avg6 * 100 / plan).toStringAsFixed(0)}%' : null),
              ]),
            ),
            const SectionTitle('월별 (만 원)', trailing: '점선 = 계획'),
            Panel(
              child: SizedBox(
                height: 160,
                child: BarChart(BarChartData(
                  maxY: maxY <= 0 ? 1 : maxY,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    if (plan > 0) HorizontalLine(y: plan / 10000, color: p.ink, strokeWidth: 1, dashArray: [4, 3]),
                  ]),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (v, _) =>
                            Text(v.toStringAsFixed(0), style: TextStyle(fontSize: 10, color: p.textMuted)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= last12.length) return const SizedBox.shrink();
                          return Text('${int.parse(last12[i].substring(5))}', style: TextStyle(fontSize: 10, color: p.textMuted));
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < last12.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: byMonth[last12[i]]! / 10000,
                          width: 12,
                          borderRadius: BorderRadius.circular(3),
                          color: last12[i] == month
                              ? (plan > 0 && byMonth[last12[i]]! > plan * 1.05 ? p.over : p.info)
                              : p.textSub.withValues(alpha: 0.45),
                        ),
                      ]),
                  ],
                )),
              ),
            ),
            SectionTitle('무엇에 썼나', trailing: focus == null ? '눌러서 그 항목만 보기' : '다시 누르면 전체'),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: AppGap.md, vertical: AppGap.xs),
              child: Column(children: [
                for (final e in partList)
                  AmountRow(
                    title: e.key,
                    sub: total > 0 ? '${(e.value * 100 / total).toStringAsFixed(0)}%' : null,
                    amount: won(e.value),
                    selected: focus == e.key,
                    dimmed: focus != null && focus != e.key,
                    onTap: () => setState(() => _focus = focus == e.key ? null : e.key),
                  ),
                if (partList.isEmpty) Padding(padding: const EdgeInsets.all(AppGap.md), child: Text('이 달 거래가 없어요', style: t.labelMedium)),
              ]),
            ),
            SectionTitle(focus == null ? '많이 쓴 곳' : '많이 쓴 곳 · $focus', trailing: focus == null ? null : won(shownTotal)),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: AppGap.md, vertical: AppGap.xs),
              child: Column(children: [
                for (final e in topMerchants.take(focus == null ? 5 : 10)) AmountRow(title: e.key, amount: won(e.value)),
              ]),
            ),
            SectionTitle(focus == null ? '거래' : '거래 · $focus', trailing: '${shown.length}건'),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: AppGap.md, vertical: AppGap.xs),
              child: Column(children: [
                for (final x in shown)
                  AmountRow(
                    title: x.merchant,
                    sub: '${x.date.substring(5).replaceAll('-', '/')} · ${x.livingPart} · ${x.payment}',
                    amount: won(-x.amount),
                    amountColor: x.amount > 0 ? p.under : null,
                  ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
