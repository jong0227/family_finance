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
          final topMerchants = (merchants.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .take(focus == null ? 5 : 10)
              .toList();
          final maxY = [...byMonth.values, plan].fold<int>(0, (a, b) => a > b ? a : b) / 10000 * AppChart.headroom;
          final over = plan > 0 && total > plan * 1.05;
          final axis = AppText.micro.copyWith(color: p.textMuted).tnum;

          return ListView(padding: const EdgeInsets.only(bottom: AppGap.xl), children: [
            MonthSwitcher(month: month, months: monthList, onChanged: ref.read(selectedMonthProvider.notifier).set),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppGap.page, vertical: AppGap.xs),
              child: Row(children: [
                KpiTile(
                  label: '이 달',
                  value: man(total),
                  sub: plan <= 0
                      ? null
                      : over
                          ? '계획 ${man(plan)} · ${man(total - plan)} 초과'
                          : '계획 ${man(plan)}',
                  valueColor: over ? p.over : null,
                ),
                const SizedBox(width: AppGap.sm),
                KpiTile(label: '최근 6개월 평균', value: man(avg6), sub: plan > 0 ? '계획의 ${(avg6 * 100 / plan).toStringAsFixed(0)}%' : null),
              ]),
            ),
            SectionCard(
              title: '월별',
              trailing: '점선 = 계획 · 넘친 부분 = 빨강',
              child: SizedBox(
                height: AppChart.heightSm,
                child: BarChart(BarChartData(
                  maxY: maxY <= 0 ? 1 : maxY,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    if (plan > 0)
                      HorizontalLine(
                          y: plan / 10000, color: p.ink, strokeWidth: AppChart.planStroke, dashArray: AppChart.planDash),
                  ]),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: AppChart.axisReserved,
                        getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(0)}만', style: axis),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= last12.length) return const SizedBox.shrink();
                          final now = last12[i] == month;
                          return Text('${int.parse(last12[i].substring(5))}',
                              style: now ? axis.copyWith(color: p.ink, fontWeight: FontWeight.w600) : axis);
                        },
                      ),
                    ),
                  ),
                  // 6.2: 고른 달만 진한 잉크, 지난 달은 옅게. 계획을 넘으면 넘은 부분만 over.mark.
                  barGroups: [
                    for (var i = 0; i < last12.length; i++) _bar(context, i, byMonth[last12[i]]!, plan, last12[i] == month),
                  ],
                )),
              ),
            ),
            SectionCard(
              title: '무엇에 썼나',
              trailing: focus == null ? '눌러서 그 항목만 보기' : '다시 누르면 전체',
              list: true,
              child: Column(children: [
                for (final (i, e) in partList.indexed)
                  AmountRow(
                    title: e.key,
                    sub: total > 0 ? '${(e.value * 100 / total).toStringAsFixed(0)}%' : null,
                    amount: man(e.value),
                    selected: focus == e.key,
                    dimmed: focus != null && focus != e.key,
                    divider: i < partList.length - 1,
                    onTap: () => setState(() => _focus = focus == e.key ? null : e.key),
                  ),
                if (partList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppGap.xs),
                    child: Text('이 달 거래가 없어요', style: AppText.body.copyWith(color: p.textSub)),
                  ),
              ]),
            ),
            SectionCard(
              title: focus == null ? '많이 쓴 곳' : '많이 쓴 곳 · $focus',
              trailing: focus == null ? null : man(shownTotal),
              list: true,
              child: Column(children: [
                for (final (i, e) in topMerchants.indexed)
                  AmountRow(title: e.key, amount: man(e.value), divider: i < topMerchants.length - 1),
              ]),
            ),
            SectionCard(
              title: focus == null ? '거래' : '거래 · $focus',
              trailing: '${shown.length}건',
              list: true,
              child: Column(children: [
                for (final (i, x) in shown.indexed)
                  AmountRow(
                    title: x.merchant,
                    sub: '${x.date.substring(5).replaceAll('-', '/')} · ${x.livingPart} · ${x.payment}',
                    amount: txWon(x.amount),
                    amountColor: x.amount > 0 ? p.under : null,
                    divider: i < shown.length - 1,
                  ),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  static BarChartGroupData _bar(BuildContext context, int x, int amount, int plan, bool now) {
    final p = context.palette;
    final y = amount / 10000, planY = plan / 10000;
    final base = now ? p.ink : p.ink.withValues(alpha: AppAlpha.barFill);
    final overColor = now ? p.overMark : p.overMark.withValues(alpha: AppAlpha.barFill);
    final overflow = plan > 0 && amount > plan * 1.05;
    return BarChartGroupData(x: x, barRods: [
      BarChartRodData(
        toY: y,
        width: AppChart.barWidth,
        color: base,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xs)),
        rodStackItems: overflow
            ? [BarChartRodStackItem(0, planY, base), BarChartRodStackItem(planY, y, overColor)]
            : const [],
      ),
    ]);
  }
}
