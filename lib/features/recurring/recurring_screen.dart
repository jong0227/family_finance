import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ninedogs_core/ninedogs_core.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/format/won.dart';

/// 정기 — 구독 목록 (M0: Ninedogs 와 같은 데이터를 실시간 읽기만). 고정지출·달력·카드는 M3.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(subscriptionsProvider);
    final people = ref.watch(peopleProvider).value ?? People.defaults;
    final p = context.palette;
    final theme = Theme.of(context);

    return subs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('구독을 읽지 못했어요\n$e', textAlign: TextAlign.center)),
      data: (all) {
        final active = all.where((s) => s.isActive).toList()
          ..sort((a, b) => b.monthlyCost.minor.compareTo(a.monthlyCost.minor));
        final krw = active.where((s) => s.currency == Money.krw);
        final total = krw.fold<int>(0, (sum, s) => sum + s.monthlyCost.minor);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader('정기', trailing: Text('구독 ${active.length}개 · 월 ${won(total)}', style: theme.textTheme.labelMedium)),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
                itemCount: active.length,
                separatorBuilder: (_, _) => Divider(color: p.line),
                itemBuilder: (context, i) {
                  final s = active[i];
                  final owner = s.owner;
                  return SizedBox(
                    height: AppSize.row + 8,
                    child: Row(children: [
                      Expanded(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Flexible(child: Text(s.name, style: theme.textTheme.bodyLarge, overflow: TextOverflow.ellipsis)),
                          if (owner != null) ...[
                            const SizedBox(width: 4),
                            OwnerBadge(name: people.nameOf(owner), color: p.person(owner)),
                          ],
                        ]),
                      ),
                      Text(
                        s.currency == Money.krw ? won(s.monthlyCost.minor) : s.monthlyCost.format(),
                        style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
