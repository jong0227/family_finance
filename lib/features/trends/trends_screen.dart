import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import '../../domain/finance_models.dart';

/// 추이 — 월별 지출과 생활비 항목별 월 변화.
class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(monthsProvider).value ?? const <MonthAgg>[];
    final plan = ref.watch(planProvider).value;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    if (months.isEmpty) return const ComingSoon('추이', '아직 데이터가 없어요');

    final last12 = months.length > 12 ? months.sublist(months.length - 12) : months;
    final last6 = months.length > 6 ? months.sublist(months.length - 6) : months;
    final livingPlan = plan?.livingPlan ?? const <String, int>{};
    final maxY = last12.map((m) => m.regular + m.oneOff).fold<int>(0, (a, b) => a > b ? a : b) / 10000 * 1.1;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppGap.xl),
      children: [
        const PageHeader('추이'),
        const SectionTitle('월별 지출', trailing: '만 원 · 진한 칸 = 평소, 옅은 칸 = 일회성'),
        Panel(
          child: SizedBox(
            height: 180,
            child: BarChart(BarChartData(
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: p.line, strokeWidth: 1, dashArray: [3, 3]),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: TextStyle(fontSize: 10, color: p.textMuted)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= last12.length) return const SizedBox.shrink();
                      return Text('${int.parse(last12[i].month.substring(5))}월',
                          style: TextStyle(fontSize: 10, color: p.textMuted));
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < last12.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: (last12[i].regular + last12[i].oneOff) / 10000,
                      width: 14,
                      borderRadius: BorderRadius.circular(3),
                      rodStackItems: [
                        BarChartRodStackItem(0, last12[i].regular / 10000, p.info),
                        BarChartRodStackItem(last12[i].regular / 10000, (last12[i].regular + last12[i].oneOff) / 10000,
                            p.info.withValues(alpha: 0.25)),
                      ],
                    ),
                  ]),
              ],
            )),
          ),
        ),
        const SectionTitle('생활비 항목별 월 변화', trailing: '만 원 · 빨강 = 계획 초과'),
        Panel(
          padding: const EdgeInsets.all(AppGap.sm),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 30,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 36,
              horizontalMargin: 6,
              columnSpacing: 14,
              dividerThickness: 1,
              headingTextStyle: TextStyle(fontSize: 11, color: p.textMuted, fontWeight: FontWeight.w600),
              columns: [
                const DataColumn(label: Text('항목')),
                const DataColumn(label: Text('계획'), numeric: true),
                for (final m in last6) DataColumn(label: Text('${int.parse(m.month.substring(5))}월'), numeric: true),
              ],
              rows: [
                for (final g in livingGroups)
                  DataRow(cells: [
                    DataCell(Text(livingLabels[g] ?? g, style: t.bodySmall?.copyWith(color: p.ink))),
                    DataCell(Text(man(livingPlan[g] ?? 0), style: t.bodySmall)),
                    for (final m in last6)
                      DataCell(Text(
                        man(m.living[g] ?? 0),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (livingPlan[g] ?? 0) > 0 && (m.living[g] ?? 0) > (livingPlan[g] ?? 0) * 1.05 && !m.partial
                              ? p.over
                              : p.ink,
                        ),
                      )),
                  ]),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppGap.page),
          child: Text('줄일 것 · 여유 있는 것 진단은 다음 단계(M2)에서 붙어요', style: t.labelSmall),
        ),
      ],
    );
  }
}
