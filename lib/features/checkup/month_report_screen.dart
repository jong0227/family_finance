import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import '../../domain/finance_models.dart';
import '../../domain/month_report.dart';

/// 월말 점검 리포트(S4) — 고른 달의 계획 대비·생활비·많이 쓴 곳·일회성·진단. 읽기 전용.
class MonthReportScreen extends ConsumerWidget {
  const MonthReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = ref.watch(monthsProvider).value ?? const <MonthAgg>[];
    final month = ref.watch(currentMonthProvider);
    final plan = ref.watch(planProvider).value;
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('월말 점검 리포트')),
      body: month == null || plan == null
          ? const Center(child: Text('데이터를 기다리는 중이에요'))
          : Builder(builder: (context) {
              final agg = months.where((m) => m.month == month).firstOrNull;
              final txs = ref.watch(transactionsProvider(month)).value ?? const <Tx>[];
              final r = buildMonthReport(
                  month: month, agg: agg, plan: plan, txs: txs, diagnosis: ref.watch(diagnosisProvider));
              return ListView(padding: const EdgeInsets.only(bottom: AppGap.xl), children: [
                MonthSwitcher(
                  month: month,
                  months: [for (final m in months) m.month],
                  onChanged: ref.read(selectedMonthProvider.notifier).set,
                  note: r.partial ? '진행 중인 달' : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
                  child: Row(children: [
                    KpiTile(label: '소비', value: man(r.consumption), sub: '계획 ${man(r.planTotal)}'),
                    const SizedBox(width: AppGap.sm),
                    KpiTile(
                      label: r.diff > 0 ? '계획 초과' : '계획 이내',
                      value: man(r.diff.abs()),
                      valueColor: r.diff > 0 ? p.over : p.under,
                      sub: '저축 구분 제외한 계획 기준',
                    ),
                  ]),
                ),
                SectionCard(
                  title: '생활비 — 초과·여유',
                  trailing: '초과 ${man(r.livingOver)} · 여유 ${man(r.livingUnder)}',
                  list: true,
                  child: Column(children: [
                    for (final (i, l) in r.living.indexed)
                      AmountRow(
                        title: livingLabels[l.group] ?? l.group,
                        sub: '계획 ${man(l.plan)} · 실제 ${man(l.actual)}',
                        amount: '${l.diff > 0 ? '+' : l.diff < 0 ? minus : ''}${man(l.diff.abs())}',
                        amountColor: l.diff > 0 ? p.over : (l.diff < 0 ? p.under : null),
                        divider: i < r.living.length - 1,
                      ),
                    if (r.living.isEmpty) Text('생활비 계획이 없어요', style: AppText.caption.copyWith(color: p.textMuted)),
                  ]),
                ),
                SectionCard(
                  title: '많이 쓴 곳',
                  trailing: '일회성 제외 · 상위 ${r.topMerchants.length}',
                  list: true,
                  child: Column(children: [
                    for (final (i, m) in r.topMerchants.indexed)
                      AmountRow(title: m.name, sub: '${m.count}건', amount: man(m.amount), divider: i < r.topMerchants.length - 1),
                    if (r.topMerchants.isEmpty) Text('거래가 없어요', style: AppText.caption.copyWith(color: p.textMuted)),
                  ]),
                ),
                SectionCard(
                  title: '일회성',
                  trailing: '${r.oneOffs.length}건 · ${man(r.oneOffTotal)}',
                  list: true,
                  child: Column(children: [
                    for (final (i, t) in r.oneOffs.indexed)
                      AmountRow(
                        title: t.merchant,
                        sub: [t.date.length >= 10 ? t.date.substring(5).replaceAll('-', '/') : t.date, if (t.note.isNotEmpty) t.note].join(' · '),
                        amount: won(-t.amount),
                        divider: i < r.oneOffs.length - 1,
                      ),
                    if (r.oneOffs.isEmpty) Text('없음', style: AppText.caption.copyWith(color: p.textMuted)),
                  ]),
                ),
                SectionCard(
                  title: '진단 요약',
                  trailing: '최근 완전한 달 기준',
                  list: true,
                  child: Column(children: [
                    for (final d in r.cut)
                      AmountRow(title: d.label, sub: d.evidence, amount: '+${man(d.diff)}', amountColor: p.over),
                    for (final d in r.slack)
                      AmountRow(title: d.label, sub: d.evidence, amount: '$minus${man(d.diff.abs())}', amountColor: p.under),
                    if (r.cut.isEmpty && r.slack.isEmpty)
                      Text('줄일 것·여유로 판정된 항목이 없어요', style: AppText.caption.copyWith(color: p.textMuted)),
                  ]),
                ),
                const FootNote('읽기 전용 · 계획 조정은 정기 탭에서 · 쿠팡 미확인 비율·PDF 공유는 추후'),
              ]);
            }),
    );
  }
}
