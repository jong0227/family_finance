/// 월말 점검 리포트(S4) 집계. 읽기 전용. Flutter·Firebase 를 모른다.
/// 진단 하이라이트는 [diagnose] 결과를 그대로 쓴다(여기서 다시 판정하지 않는다).
library;

import 'diagnosis.dart';
import 'finance_models.dart';

class LivingLine {
  const LivingLine(this.group, this.plan, this.actual);
  final String group;
  final int plan, actual;
  int get diff => actual - plan; // 양수 = 초과
}

class MerchantLine {
  const MerchantLine(this.name, this.amount, this.count);
  final String name;
  final int amount, count;
}

class MonthReport {
  const MonthReport({
    required this.month,
    required this.partial,
    required this.consumption,
    required this.planTotal,
    required this.living,
    required this.topMerchants,
    required this.oneOffs,
    required this.oneOffTotal,
    required this.cut,
    required this.slack,
  });
  final String month;
  final bool partial;

  /// 실제 소비(월 집계) vs 계획 합계(저축 구분 제외).
  final int consumption, planTotal;
  final List<LivingLine> living;
  final List<MerchantLine> topMerchants;
  final List<Tx> oneOffs;
  final int oneOffTotal;
  final List<DiagnosisRow> cut, slack;

  int get diff => consumption - planTotal;
  int get livingOver => living.where((l) => l.diff > 0).fold(0, (a, l) => a + l.diff);
  int get livingUnder => living.where((l) => l.diff < 0).fold(0, (a, l) => a - l.diff);
}

/// [txs] 는 그 달의 거래(소비만 쓴다). 지출은 amount 음수. 일회성은 가맹점 순위에서 빼고 따로 모은다.
MonthReport buildMonthReport({
  required String month,
  required MonthAgg? agg,
  required Plan plan,
  required List<Tx> txs,
  DiagnosisResult? diagnosis,
  Set<String> planExcludeGroups = const {'저축'},
  int topN = 5,
}) {
  final planTotal =
      plan.items.where((i) => !planExcludeGroups.contains(i.group)).fold<int>(0, (a, i) => a + i.monthlyAmount);
  final lp = plan.livingPlan;
  final keys = <String>[
    ...livingGroups.where((g) => lp.containsKey(g) || (agg?.living[g] ?? 0) != 0),
    ...lp.keys.where((g) => !livingGroups.contains(g)),
  ];
  final living = [for (final g in keys) LivingLine(g, lp[g] ?? 0, agg?.living[g] ?? 0)]
    ..sort((a, b) => b.diff.compareTo(a.diff));

  final spend = txs.where((t) => t.kind == '소비' && t.amount < 0 && t.month == month).toList();
  final sums = <String, (int, int)>{};
  for (final t in spend.where((t) => !t.oneOff)) {
    final cur = sums[t.merchantKey] ?? (0, 0);
    sums[t.merchantKey] = (cur.$1 - t.amount, cur.$2 + 1);
  }
  final top = [for (final e in sums.entries) MerchantLine(e.key, e.value.$1, e.value.$2)]
    ..sort((a, b) => b.amount.compareTo(a.amount));
  final oneOffs = spend.where((t) => t.oneOff).toList()..sort((a, b) => a.amount.compareTo(b.amount));

  return MonthReport(
    month: month,
    partial: agg?.partial ?? false,
    consumption: agg?.consumption ?? 0,
    planTotal: planTotal,
    living: living,
    topMerchants: top.take(topN).toList(),
    oneOffs: oneOffs,
    oneOffTotal: oneOffs.fold(0, (a, t) => a - t.amount),
    cut: (diagnosis?.cut ?? const []).take(3).toList(),
    slack: (diagnosis?.slack ?? const []).take(3).toList(),
  );
}
