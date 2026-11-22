import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ninedogs_core/ninedogs_core.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import 'plan_item_sheet.dart';
import 'subscription_sheet.dart';

/// 정기 — 고정지출(계획, 결제 카드 → 출금 통장) │ 구독(Ninedogs 와 같은 데이터).
class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  int _tab = 0;
  String? _group; // 구분 필터 (null = 전체)

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('정기',
          trailing: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('고정지출')),
              ButtonSegment(value: 1, label: Text('구독')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          )),
      Expanded(child: _tab == 0 ? _fixed(context) : _subscriptions(context)),
    ]);
  }

  Widget _fixed(BuildContext context) {
    final plan = ref.watch(planProvider).value;
    if (plan == null) return const Center(child: CircularProgressIndicator());
    final groups = <String>[];
    for (final i in plan.items) {
      if (!groups.contains(i.group)) groups.add(i.group);
    }
    final items = plan.items.where((i) => _group == null || i.group == _group).toList();
    final total = items.fold<int>(0, (a, i) => a + i.monthlyAmount);

    return ListView(padding: const EdgeInsets.only(bottom: AppGap.xl), children: [
      ChipBar(children: [
        ChoiceChip(label: const Text('전체'), selected: _group == null, onSelected: (_) => setState(() => _group = null)),
        for (final g in groups)
          ChoiceChip(label: Text(g), selected: _group == g, onSelected: (_) => setState(() => _group = g)),
      ]),
      SectionCard(
        title: '월 ${man(total)}',
        trailing: '${items.length}개 · 계획 기준',
        list: true,
        child: Column(children: [
          for (final (n, i) in items.indexed)
            AmountRow(
              onTap: () => showPlanItemSheet(context, item: i, plan: plan),
              title: i.name,
              sub: [
                i.category,
                if (i.payment.isNotEmpty) i.payment,
                if ((i.accountName ?? '').isNotEmpty) '→ ${i.accountName}',
                if ((i.payDayText ?? '').isNotEmpty) i.payDayText!,
              ].join(' · '),
              amount: won(i.monthlyAmount),
              divider: n < items.length - 1,
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showPlanItemSheet(context, plan: plan, initialGroup: _group),
            icon: const Icon(Icons.add, size: AppSize.icon),
            label: const Text('항목 추가'),
          ),
        ),
      ),
      const FootNote('→ 통장: 그 카드값이 빠지는 통장 · 항목을 누르면 고쳐요'),
    ]);
  }

  Widget _subscriptions(BuildContext context) {
    final subs = ref.watch(subscriptionsProvider);
    final people = ref.watch(peopleProvider).value ?? People.defaults;
    return subs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('구독을 읽지 못했어요\n$e', textAlign: TextAlign.center)),
      data: (all) {
        final active = all.where((s) => s.isActive).toList()
          ..sort((a, b) => b.monthlyCost.minor.compareTo(a.monthlyCost.minor));
        final total = active.where((s) => s.currency == Money.krw).fold<int>(0, (sum, s) => sum + s.monthlyCost.minor);
        final readOnly = ref.watch(subscriptionsReadOnlyProvider);
        return ListView(padding: const EdgeInsets.only(top: AppGap.xs, bottom: AppGap.xl), children: [
          if (readOnly)
            const Padding(padding: EdgeInsets.symmetric(horizontal: AppGap.page), child: ReadOnlyBanner()),
          SectionCard(
            title: '월 ${man(total)}',
            trailing: '구독 ${active.length}개 · Ninedogs 와 같은 데이터',
            list: true,
            child: Column(children: [
              for (final (i, s) in active.indexed)
                AmountRow(
                  onTap: () => showSubscriptionSheet(context, sub: s),
                  title: s.name,
                  leading: s.owner == null ? null : OwnerBadge(name: people.nameOf(s.owner!), owner: s.owner!),
                  sub: [s.cycle.label, if ((s.paymentMethod ?? '').isNotEmpty) s.paymentMethod!].join(' · '),
                  amount: s.currency == Money.krw ? won(s.monthlyCost.minor) : s.monthlyCost.format(),
                  divider: i < active.length - 1,
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: readOnly ? null : () => showSubscriptionSheet(context),
                icon: const Icon(Icons.add, size: AppSize.icon),
                label: const Text('구독 추가'),
              ),
            ),
          ),
        ]);
      },
    );
  }
}
