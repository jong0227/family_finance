import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import '../../domain/finance_models.dart';
import '../trends/living_detail_screen.dart';

/// 이번 달 — 계획 대비 생활비, 분류별 지출. "무엇에 많이 썼나"가 먼저.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// "무엇에 썼나"에서 고른 분류(포커스). null 이면 전체.
  String? _focus;

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: AppGap.page, vertical: AppGap.xs),
              child: Row(children: [
                KpiTile(label: '지출 (일회성 제외)', value: man(m.regular), sub: won(m.regular)),
                const SizedBox(width: AppGap.sm),
                KpiTile(
                  label: '생활비 / 계획',
                  value: man(m.livingTotal),
                  sub: livingPlanTotal <= 0
                      ? null
                      : over
                          ? '${man(m.livingTotal - livingPlanTotal)} 초과'
                          : '계획 ${man(livingPlanTotal)}',
                  valueColor: over ? p.over : null,
                ),
                const SizedBox(width: AppGap.sm),
                KpiTile(label: '일회성 (100만+)', value: man(m.oneOff), sub: m.oneOff > 0 ? '따로 봐요' : '없음'),
              ]),
            ),
            SectionCard(
              title: '생활비 — 계획 대비',
              trailing: m.partial ? '이번 달은 진행 중' : null,
              child: Column(children: [
                for (final g in livingGroups)
                  InkWell(
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => LivingDetailScreen(group: g))),
                    child: BudgetRow(
                      name: livingLabels[g] ?? g,
                      actual: m.living[g] ?? 0,
                      plan: livingPlan[g] ?? 0,
                    ),
                  ),
              ]),
            ),
            SectionCard(
              title: '무엇에 썼나',
              trailing: _focus == null ? '일회성 제외 · 눌러서 그 분류만' : '다시 누르면 전체',
              list: true,
              child: Column(children: [
                for (final (i, e) in cats.indexed)
                  AmountRow(
                    title: e.key,
                    sub: m.regular > 0 ? '${(e.value * 100 / m.regular).toStringAsFixed(0)}%' : null,
                    amount: man(e.value),
                    selected: _focus == e.key,
                    dimmed: _focus != null && _focus != e.key,
                    divider: i < cats.length - 1,
                    onTap: () => setState(() => _focus = _focus == e.key ? null : e.key),
                  ),
              ]),
            ),
            if (_focus != null) _CategoryFocus(month: m.month, category: _focus!),
          ],
        );
      },
    );
  }
}

/// 포커스된 분류 안에서 많이 쓴 곳과 거래 (그 달, 일회성 제외).
class _CategoryFocus extends ConsumerWidget {
  const _CategoryFocus({required this.month, required this.category});
  final String month, category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(transactionsProvider(month)).value ?? const [];
    final p = context.palette;
    final shown = txs.where((x) => x.kind == '소비' && !x.oneOff && x.category == category).toList();
    final merchants = <String, int>{};
    for (final x in shown) {
      merchants[x.merchantKey] = (merchants[x.merchantKey] ?? 0) - x.amount;
    }
    final top = (merchants.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(10).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionCard(
        title: '많이 쓴 곳 · $category',
        trailing: '${merchants.length}곳',
        list: true,
        child: Column(children: [
          for (final (i, e) in top.indexed) AmountRow(title: e.key, amount: man(e.value), divider: i < top.length - 1),
        ]),
      ),
      SectionCard(
        title: '거래 · $category',
        trailing: '${shown.length}건',
        list: true,
        child: Column(children: [
          for (final (i, x) in shown.indexed)
            AmountRow(
              title: x.merchant,
              sub: '${x.date.substring(5).replaceAll('-', '/')} · ${x.payment}',
              amount: txWon(x.amount),
              amountColor: x.amount > 0 ? p.under : null,
              divider: i < shown.length - 1,
            ),
        ]),
      ),
    ]);
  }
}
