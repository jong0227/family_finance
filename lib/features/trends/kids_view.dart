import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import '../../domain/finance_models.dart';
import '../../domain/kid_spending.dart';

/// S7 아이별 지출 — 칩으로 고른 계획 분류(사용자 분류 체계)와 생활비 구성의 지출.
/// 칩 이름은 전부 데이터에서 읽고, 고른 값은 기기에 기억한다.
/// 계획 분류는 항목별 계획·최근 실제(한 값), 생활비 구성은 월별 실제(거래 기준).
class KidsView extends ConsumerWidget {
  const KidsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider).value;
    final months = ref.watch(monthsProvider).value ?? const <MonthAgg>[];
    final livingTx = ref.watch(allLivingTxProvider);
    final selected = ref.watch(kidCategoriesProvider);
    final p = context.palette;
    if (plan == null) {
      return Center(child: Text('계획이 있어야 볼 수 있어요', style: AppText.body.copyWith(color: p.textSub)));
    }
    final categories = <String>[];
    for (final i in plan.items) {
      if (!categories.contains(i.category)) categories.add(i.category);
    }
    final parts = livingPartNames(livingTx);
    final spending = kidSpending(plan: plan, months: months, livingTx: livingTx, selected: selected);

    void toggle(String key) {
      final next = {...selected};
      next.contains(key) ? next.remove(key) : next.add(key);
      ref.read(kidCategoriesProvider.notifier).set(next);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppGap.xl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppGap.page, AppGap.xs, AppGap.page, 0),
          child: Text('아이 것인 분류와 생활비 구성을 골라 보세요 (기억해요)',
              style: AppText.caption.copyWith(color: p.textSub)),
        ),
        ChipBar(children: [
          for (final c in categories)
            FilterChip(
                label: Text(c), selected: selected.contains(kidCategoryKey(c)), onSelected: (_) => toggle(kidCategoryKey(c))),
        ]),
        if (parts.isNotEmpty)
          ChipBar(children: [
            for (final n in parts)
              FilterChip(
                  label: Text(n), selected: selected.contains(kidPartKey(n)), onSelected: (_) => toggle(kidPartKey(n))),
          ]),
        for (final r in spending.categories)
          SectionCard(
            title: r.category,
            trailing: r.recentActual == null
                ? '계획 ${man(r.plan)}'
                : '최근 실제 ${man(r.recentActual!)} / 계획 ${man(r.plan)}',
            list: true,
            child: Column(children: [
              for (final (i, it) in r.items.indexed)
                AmountRow(
                  title: it.name,
                  sub: [
                    '계획 ${man(it.monthlyAmount)}',
                    if (it.recentActual != null) '최근 실제 ${man(it.recentActual!)}',
                    if (it.living != null) '생활비 묶음',
                  ].join(' · '),
                  amount: man(it.recentActual ?? it.monthlyAmount),
                  divider: i < r.items.length - 1,
                ),
            ]),
          ),
        for (final r in spending.parts)
          SectionCard(
            title: r.part,
            trailing: '평균 ${man(r.average)} · 생활비 구성',
            child: _MonthBars(months: r.months, plan: 0),
          ),
        if (!spending.isEmpty)
          const FootNote('계획 분류는 계획 문서의 최근 실제 한 값이에요 · 생활비 구성은 월별 거래 합계(일회성 제외)'),
      ],
    );
  }
}

/// 달별 막대 한 줄씩(오래된 순). 계획 눈금은 ink 한 줄, 진행 중인 달은 옅게.
class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.months, required this.plan});
  final List<KidMonth> months;
  final int plan;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxV = [plan, ...months.map((m) => m.amount)].fold<int>(1, (a, b) => a > b ? a : b);
    return Column(children: [
      for (final m in months)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppGap.xxs),
          child: Row(children: [
            SizedBox(
              width: AppSize.numCol / 2,
              child: Text('${int.parse(m.month.substring(5))}월${m.partial ? '*' : ''}',
                  style: AppText.caption.copyWith(color: p.textSub).tnum),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth;
                final over = plan > 0 && m.amount > plan * 1.05 && !m.partial;
                final r = BorderRadius.circular(AppRadius.xs);
                return SizedBox(
                  height: AppSize.progress,
                  child: Stack(children: [
                    Container(decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: r)),
                    Container(
                      width: w * m.amount / maxV,
                      decoration: BoxDecoration(
                        color: (over ? p.overMark : p.textSub).withValues(alpha: m.partial ? AppAlpha.past : AppAlpha.barFill),
                        borderRadius: r,
                      ),
                    ),
                    if (plan > 0)
                      Positioned(
                        left: (w * plan / maxV - AppSize.planTick / 2).clamp(0.0, w - AppSize.planTick),
                        child: Container(width: AppSize.planTick, height: AppSize.progress, color: p.ink),
                      ),
                  ]),
                );
              }),
            ),
            SizedBox(
              width: AppSize.numCol,
              child: Text(man(m.amount),
                  textAlign: TextAlign.right,
                  style: AppText.label.copyWith(color: m.partial ? p.textMuted : p.ink, fontWeight: FontWeight.w500).tnum),
            ),
          ]),
        ),
      if (months.any((m) => m.partial))
        Align(
          alignment: Alignment.centerRight,
          child: Text('* 진행 중인 달', style: AppText.micro.copyWith(color: p.textMuted)),
        ),
    ]);
  }
}
