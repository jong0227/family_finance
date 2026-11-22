/// 진단 — 줄일 것 / 여유 있는 것 (SCREENS 2.4). Flutter·Firebase 를 모른다.
/// 계획과 실제는 다른 층이다: 계획을 실제에 맞춰 바꾸지 않고, 비교 결과만 낸다.
library;

import 'finance_models.dart';

/// 비교 단위 종류: 생활비 묶음(월별 근거) / 계획 항목(최근 실제 한 값).
enum DiagnosisScope { living, item }

enum Verdict {
  /// 줄일 것: 평균이 계획을 넘고, 초과한 달이 대부분.
  cut,

  /// 여유: 평균이 계획보다 한참 낮고, 낮은 달이 대부분.
  slack,

  /// 계획 안(판정 없음).
  ok,

  /// 완전한 달이 모자라 판정하지 않음.
  insufficient,
}

/// 판정 기준. 화면에 근거로 그대로 보여 줄 수 있게 값을 모아 둔다.
class DiagnosisRules {
  const DiagnosisRules({
    this.window = 6,
    this.minMonths = 3,
    this.overTolerance = 0.05,
    this.slackRatio = 0.85,
    this.share = 2 / 3,
    this.fixedGroups = const {'대출', '저축'},
  });

  /// 최근 몇 개월(완전한 달만)을 보나.
  final int window;

  /// 이보다 적은 달이면 판정하지 않는다.
  final int minMonths;

  /// 계획의 이 비율을 넘어야 "초과한 달"(±5% 는 계획대로).
  final double overTolerance;

  /// 평균이 계획의 이 비율 이하이고 낮은 달이 대부분이면 여유.
  final double slackRatio;

  /// "대부분" = 이 비율 이상의 달.
  final double share;

  /// 줄일 수 없는 고정 구분(계획 구분 이름). 이 구분만 가진 분류는 판정에서 빼고 따로 보여 준다.
  final Set<String> fixedGroups;
}

class DiagnosisRow {
  const DiagnosisRow({
    required this.key,
    required this.label,
    required this.scope,
    required this.plan,
    required this.months,
    required this.actuals,
    required this.average,
    required this.overMonths,
    required this.underMonths,
    required this.verdict,
    required this.fixed,
  });

  /// 생활비 묶음 키 또는 계획 항목 id, 그리고 화면에 쓸 이름(사용자 이름 그대로).
  final String key, label;
  final DiagnosisScope scope;
  final int plan;

  /// 근거 기간의 달(오래된 순)과 그 달의 실제 금액.
  final List<String> months;
  final List<int> actuals;
  final int average;
  final int overMonths, underMonths;
  final Verdict verdict;
  final bool fixed;

  int get n => months.length;

  /// 평균 − 계획. 양수면 초과.
  int get diff => average - plan;

  /// 평균 / 계획 (계획 0 이면 0).
  double get ratio => plan <= 0 ? 0 : average / plan;

  /// 근거 기간 문구. 예) "최근 6개월 중 5개월 초과 · 2026-05~2026-10"
  String get evidence {
    if (scope == DiagnosisScope.item) return '최근 실제 기준';
    if (n == 0) return '완전한 달 없음';
    final span = n == 1 ? months.first : '${months.first}~${months.last}';
    switch (verdict) {
      case Verdict.cut:
        return '최근 $n개월 중 $overMonths개월 초과 · $span';
      case Verdict.slack:
        return '최근 $n개월 중 $underMonths개월 여유 · $span';
      case Verdict.insufficient:
        return '완전한 달 $n개월뿐 · $span';
      case Verdict.ok:
        return '최근 $n개월 · $span';
    }
  }
}

class DiagnosisResult {
  const DiagnosisResult(this.rows);
  final List<DiagnosisRow> rows;

  /// 줄일 것(초과액 큰 순) — 고정 제외.
  List<DiagnosisRow> get cut =>
      rows.where((r) => r.verdict == Verdict.cut && !r.fixed).toList()..sort((a, b) => b.diff.compareTo(a.diff));

  /// 여유(남는 액 큰 순) — 고정 제외.
  List<DiagnosisRow> get slack =>
      rows.where((r) => r.verdict == Verdict.slack && !r.fixed).toList()..sort((a, b) => a.diff.compareTo(b.diff));

  /// 고정이라 판정에서 뺀 것.
  List<DiagnosisRow> get fixed => rows.where((r) => r.fixed).toList();


  int get cutTotal => cut.fold(0, (a, r) => a + r.diff);
  int get slackTotal => slack.fold(0, (a, r) => a - r.diff);
}

/// 비교 대상:
/// - 생활비 묶음: 월별 실제(`months.living`) vs 묶음 계획 → 최근 완전한 달 [DiagnosisRules.window]개월 근거.
/// - 계획 항목(생활비 묶음에 속하지 않는 것): 계획 문서의 `recentActual` 한 값 vs `monthlyAmount` (월별 근거 없음).
/// 월 집계의 지출 분류(`byCategoryRegular`)는 계획 분류와 이름 체계가 달라 비교에 쓰지 않는다.
DiagnosisResult diagnose({
  required Plan plan,
  required List<MonthAgg> months,
  DiagnosisRules rules = const DiagnosisRules(),
}) {
  final full = months.where((m) => !m.partial).toList()..sort((a, b) => a.month.compareTo(b.month));
  final win = full.length > rules.window ? full.sublist(full.length - rules.window) : full;
  final rows = <DiagnosisRow>[];

  for (final e in plan.livingPlan.entries) {
    final r = _seriesRow(e.key, e.value, win, rules);
    if (r != null) rows.add(r);
  }
  for (final i in plan.items) {
    if (i.living != null || i.monthlyAmount <= 0) continue;
    final actual = i.recentActual;
    if (actual == null) continue;
    final fixed = rules.fixedGroups.contains(i.group);
    final over = actual > i.monthlyAmount * (1 + rules.overTolerance);
    final under = actual < i.monthlyAmount * rules.slackRatio;
    rows.add(DiagnosisRow(
      key: i.id,
      label: i.name,
      scope: DiagnosisScope.item,
      plan: i.monthlyAmount,
      months: const [],
      actuals: [actual],
      average: actual,
      overMonths: 0,
      underMonths: 0,
      verdict: over ? Verdict.cut : (under ? Verdict.slack : Verdict.ok),
      fixed: fixed,
    ));
  }
  return DiagnosisResult(rows);
}

DiagnosisRow? _seriesRow(String key, int plan, List<MonthAgg> win, DiagnosisRules rules) {
  if (plan <= 0) return null;
  final actuals = [for (final m in win) m.living[key] ?? 0];
  if (actuals.every((a) => a <= 0)) return null;
  final avg = actuals.reduce((a, b) => a + b) ~/ actuals.length;
  final over = actuals.where((a) => a > plan * (1 + rules.overTolerance)).length;
  final under = actuals.where((a) => a < plan * (1 - rules.overTolerance)).length;
  final need = (actuals.length * rules.share).ceil();
  Verdict v;
  if (actuals.length < rules.minMonths) {
    v = Verdict.insufficient;
  } else if (avg > plan * (1 + rules.overTolerance) && over >= need) {
    v = Verdict.cut;
  } else if (avg <= plan * rules.slackRatio && under >= need) {
    v = Verdict.slack;
  } else {
    v = Verdict.ok;
  }
  return DiagnosisRow(
    key: key,
    label: key,
    scope: DiagnosisScope.living,
    plan: plan,
    months: [for (final m in win) m.month],
    actuals: actuals,
    average: avg,
    overMonths: over,
    underMonths: under,
    verdict: v,
    fixed: false,
  );
}
