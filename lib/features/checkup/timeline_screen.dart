import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import '../../domain/timeline.dart';

/// 할부·정기 대형 지출 타임라인(S2) — 계획 항목 기준. 읽기 전용.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider).value;
    final p = context.palette;
    final now = DateTime.now();
    final from = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: const Text('할부·대형 지출 타임라인')),
      body: plan == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: AppGap.xl), children: [
              for (final m in buildTimeline(plan: plan, from: from))
                SectionCard(
                  title: m.month,
                  trailing: m.entries.isEmpty ? '없음' : '${m.entries.length}건 · ${man(m.total)}',
                  list: true,
                  child: Column(children: [
                    for (final (i, e) in m.entries.indexed)
                      AmountRow(
                        title: e.name,
                        sub: switch (e.kind) {
                          TimelineKind.installment => '할부 ${e.remaining}회 남음 · ${e.endMonth}에 끝남(추정)',
                          TimelineKind.installmentUnknown => '할부 · 회차 미확인',
                          TimelineKind.large => '큰 정기 지출',
                        },
                        amount: won(e.amount),
                        divider: i < m.entries.length - 1,
                      ),
                    if (m.entries.isEmpty) Text('표시할 항목 없음', style: AppText.caption.copyWith(color: p.textMuted)),
                  ]),
                ),
              const FootNote('계획 항목에서만 만들어요 · 할부는 항목 이름·메모에 "3/10회"처럼 적힌 것만 회차를 계산(이번 달 기준) · 거래 메모·카드 알림에서 읽기, 연·분기 구독 갱신은 추후'),
            ]),
    );
  }
}
