import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import '../../domain/finance_models.dart';

/// 이번 달 — 계획 대비 생활비, 분류별 지출. "무엇에 많이 썼나"가 먼저.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(monthsProvider);
    final plan = ref.watch(planProvider).value;
    final current = ref.watch(currentMonthProvider);
    final p = context.palette;

    return months.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('불러오지 못했어요\n$e', textAlign: TextAlign.center)),
      data: (list) {
        if (list.isEmpty || current == null) {
          return const Center(child: Text('아직 가계 데이터가 없어요'));
        }
        final m = list.firstWhere((x) => x.month == current, orElse: () => list.last);
        final livingPlan = plan?.livingPlan ?? const <String, int>{};
        final livingPlanTotal = plan?.livingPlanTotal ?? 0;
        final cats = m.byCategoryRegular.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final over = livingPlanTotal > 0 && m.livingTotal > livingPlanTotal * 1.05;

        return ListView(
          padding: const EdgeInsets.only(bottom: AppGap.xl),
          children: [
            MonthSwitcher(
              month: m.month,
              months: [for (final x in list) x.month],
              onChanged: ref.read(selectedMonthProvider.notifier).set,
              note: m.partial ? '${m.coveredUntil?.substring(8) ?? ''}일까지' : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
              child: Row(children: [
                KpiTile(label: '지출 (일회성 제외)', value: man(m.regular), sub: won(m.regular)),
                const SizedBox(width: AppGap.sm),
                KpiTile(
                  label: '생활비 / 계획',
                  value: man(m.livingTotal),
                  sub: livingPlanTotal > 0 ? '계획 ${man(livingPlanTotal)}' : null,
                  valueColor: over ? p.over : null,
                ),
                const SizedBox(width: AppGap.sm),
                KpiTile(label: '일회성 (100만+)', value: man(m.oneOff), sub: m.oneOff > 0 ? '따로 봐요' : '없음'),
              ]),
            ),
            SectionTitle('생활비 — 계획 대비', trailing: m.partial ? '이번 달은 진행 중' : null),
            Panel(
              child: Column(children: [
                for (final g in livingGroups)
                  BudgetRow(
                    name: livingLabels[g] ?? g,
                    actual: m.living[g] ?? 0,
                    plan: livingPlan[g] ?? 0,
                  ),
              ]),
            ),
            SectionTitle('무엇에 썼나', trailing: '일회성 제외'),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: AppGap.md, vertical: AppGap.xs),
              child: Column(children: [
                for (final e in cats.take(10))
                  AmountRow(
                    title: e.key,
                    sub: m.regular > 0 ? '${(e.value * 100 / m.regular).toStringAsFixed(0)}%' : null,
                    amount: won(e.value),
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }
}
