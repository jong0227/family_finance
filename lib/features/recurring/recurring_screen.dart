import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ninedogs_core/ninedogs_core.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';

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
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
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
    final t = Theme.of(context).textTheme;
    if (plan == null) return const Center(child: CircularProgressIndicator());
    final groups = <String>[];
    for (final i in plan.items) {
      if (!groups.contains(i.group)) groups.add(i.group);
    }
    final items = plan.items.where((i) => _group == null || i.group == _group).toList();
    final total = items.fold<int>(0, (a, i) => a + i.monthlyAmount);

    return ListView(padding: const EdgeInsets.only(bottom: AppGap.xl), children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
        child: Wrap(spacing: AppGap.xs, children: [
          ChoiceChip(label: const Text('전체'), selected: _group == null, onSelected: (_) => setState(() => _group = null)),
          for (final g in groups)
            ChoiceChip(label: Text(g), selected: _group == g, onSelected: (_) => setState(() => _group = g)),
        ]),
      ),
      SectionTitle('월 ${won(total)}', trailing: '${items.length}개 · 계획 기준'),
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: AppGap.md, vertical: AppGap.xs),
        child: Column(children: [
          for (final i in items)
            AmountRow(
              title: i.name,
              sub: [
                i.category,
                if (i.payment.isNotEmpty) i.payment,
                if ((i.accountName ?? '').isNotEmpty) '→ ${i.accountName}',
                if ((i.payDayText ?? '').isNotEmpty) i.payDayText!,
              ].join(' · '),
              amount: won(i.monthlyAmount),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(AppGap.page),
        child: Text('카드 → 통장: 카드값이 매월 21일 빠지는 통장', style: t.labelSmall),
      ),
    ]);
  }

  Widget _subscriptions(BuildContext context) {
    final subs = ref.watch(subscriptionsProvider);
    final people = ref.watch(peopleProvider).value ?? People.defaults;
    final p = context.palette;
    return subs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('구독을 읽지 못했어요\n$e', textAlign: TextAlign.center)),
      data: (all) {
        final active = all.where((s) => s.isActive).toList()
          ..sort((a, b) => b.monthlyCost.minor.compareTo(a.monthlyCost.minor));
        final total = active.where((s) => s.currency == Money.krw).fold<int>(0, (sum, s) => sum + s.monthlyCost.minor);
        return ListView(padding: const EdgeInsets.only(bottom: AppGap.xl), children: [
          SectionTitle('월 ${won(total)}', trailing: '구독 ${active.length}개 · Ninedogs 와 같은 데이터'),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: AppGap.md, vertical: AppGap.xs),
            child: Column(children: [
              for (final s in active)
                AmountRow(
                  title: s.name,
                  leading: s.owner == null
                      ? null
                      : OwnerBadge(name: people.nameOf(s.owner!), color: p.person(s.owner!)),
                  sub: [s.cycle.label, if ((s.paymentMethod ?? '').isNotEmpty) s.paymentMethod!].join(' · '),
                  amount: s.currency == Money.krw ? won(s.monthlyCost.minor) : s.monthlyCost.format(),
                ),
            ]),
          ),
        ]);
      },
    );
  }
}
