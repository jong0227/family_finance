import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import '../../domain/finance_models.dart';
import 'diagnosis_view.dart';
import 'kids_view.dart';
import 'living_detail_screen.dart';

/// 추이 — 월별 지출과 생활비 항목별 월 변화.
class _TrendsList extends ConsumerWidget {
  const _TrendsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(monthsProvider).value ?? const <MonthAgg>[];
    final plan = ref.watch(planProvider).value;
    final current = ref.watch(currentMonthProvider);
    final p = context.palette;
    if (months.isEmpty) return const Center(child: Text('아직 데이터가 없어요'));

    final last12 = months.length > 12 ? months.sublist(months.length - 12) : months;
    final last6 = months.length > 6 ? months.sublist(months.length - 6) : months;
    final livingPlan = plan?.livingPlan ?? const <String, int>{};
    final maxY = last12.map((m) => m.regular + m.oneOff).fold<int>(0, (a, b) => a > b ? a : b) / 10000 * AppChart.headroom;
    final axis = AppText.micro.copyWith(color: p.textMuted).tnum;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppGap.xl),
      children: [

        SectionCard(
          title: '월별 지출',
          trailing: '진한 = 평소 · 옅은 = 일회성',
          child: SizedBox(
            height: AppChart.height,
            child: BarChart(BarChartData(
              maxY: maxY <= 0 ? 1 : maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: p.line, strokeWidth: AppChart.gridStroke, dashArray: AppChart.gridDash),
              ),
              borderData: FlBorderData(show: false),
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
                      final now = last12[i].month == current;
                      return Text('${int.parse(last12[i].month.substring(5))}월',
                          style: now ? axis.copyWith(color: p.ink, fontWeight: FontWeight.w600) : axis);
                    },
                  ),
                ),
              ),
              // 색은 무채색 잉크만(6.2): 고른 달만 진하게, 지난 달은 옅게. 파랑(info)은 "안내" 뜻이라 막대에 쓰지 않는다.
              barGroups: [
                for (var i = 0; i < last12.length; i++)
                  () {
                    final m = last12[i];
                    final now = m.month == current;
                    final base = now ? p.ink : p.ink.withValues(alpha: AppAlpha.barFill);
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: (m.regular + m.oneOff) / 10000,
                        width: AppChart.barWidth,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xs)),
                        rodStackItems: [
                          BarChartRodStackItem(0, m.regular / 10000, base),
                          BarChartRodStackItem(m.regular / 10000, (m.regular + m.oneOff) / 10000,
                              p.ink.withValues(alpha: now ? AppAlpha.past : AppAlpha.faint)),
                        ],
                      ),
                    ]);
                  }(),
              ],
            )),
          ),
        ),
        SectionCard(
          title: '생활비 항목별 월 변화',
          trailing: '빨강 = 계획 초과 · 눌러서 세부',
          list: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: AppSize.tableHead,
              dataRowMinHeight: AppSize.rowDense,
              dataRowMaxHeight: AppSize.rowDense,
              horizontalMargin: AppGap.xs,
              columnSpacing: AppGap.md,
              showCheckboxColumn: false,
              columns: [
                const DataColumn(label: Text('항목')),
                const DataColumn(label: Text('계획'), numeric: true),
                for (final m in last6)
                  DataColumn(
                    label: Text('${int.parse(m.month.substring(5))}월',
                        style: m.month == current ? TextStyle(color: p.ink, fontWeight: FontWeight.w600) : null),
                    numeric: true,
                  ),
              ],
              rows: [
                for (final g in livingGroups)
                  DataRow(
                    onSelectChanged: (_) => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => LivingDetailScreen(group: g))),
                    cells: [
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(livingLabels[g] ?? g, style: AppText.body),
                        Icon(Icons.chevron_right, size: AppSize.icon, color: p.textMuted),
                      ])),
                      DataCell(Text(man(livingPlan[g] ?? 0),
                          style: AppText.label.copyWith(color: p.textMuted, fontWeight: FontWeight.w400).tnum)),
                      for (final m in last6) DataCell(_cell(context, m, livingPlan[g] ?? 0, m.living[g] ?? 0, current)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 표 칸(7.6): 고른 달 열만 ink w600, 지난 달은 textSub w400. 초과는 숫자만 빨강(칸 배경은 칠하지 않음).
  static Widget _cell(BuildContext context, MonthAgg m, int plan, int actual, String? current) {
    final p = context.palette;
    final now = m.month == current;
    final over = plan > 0 && actual > plan * 1.05 && !m.partial;
    return Text(
      man(actual),
      style: AppText.label
          .copyWith(
            color: over ? p.over : (now ? p.ink : p.textSub),
            fontWeight: now || over ? FontWeight.w600 : FontWeight.w400,
          )
          .tnum,
    );
  }
}

/// 추이 탭: 추이 │ 진단 │ 아이별 (SCREENS 2.2·2.4, S7).
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader('추이',
            trailing: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('추이')),
                ButtonSegment(value: 1, label: Text('진단')),
                ButtonSegment(value: 2, label: Text('아이별')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            )),
        Expanded(child: IndexedStack(index: _tab, children: const [_TrendsList(), DiagnosisView(), KidsView()])),
      ]);
}
