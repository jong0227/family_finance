/// S8 절감 시뮬레이터 — 고른 항목을 줄이면 월·연 얼마인지. 계획을 바꾸지 않고 계산만 한다.
library;

enum ReductionMode { percent, amount }

class SimInput {
  const SimInput({required this.key, required this.plan, required this.mode, required this.value});
  final String key;

  /// 항목의 월 계획 금액.
  final int plan;
  final ReductionMode mode;

  /// percent 면 0~100, amount 면 원.
  final int value;
}

class SimLine {
  const SimLine(this.key, this.plan, this.monthlySaving);
  final String key;
  final int plan;
  final int monthlySaving;

  int get newPlan => plan - monthlySaving;
}

class SimResult {
  const SimResult(this.lines, this.planTotal);
  final List<SimLine> lines;

  /// 비교 기준이 되는 전체 월 계획.
  final int planTotal;

  int get monthly => lines.fold(0, (a, l) => a + l.monthlySaving);
  int get annual => monthly * 12;
  int get newPlanTotal => planTotal - monthly;

  /// 전체 계획 대비 절감 비율(0~1).
  double get shareOfPlan => planTotal <= 0 ? 0 : monthly / planTotal;
}

/// 항목 계획 금액을 넘는 절감·음수는 잘라 낸다.
SimResult simulateSavings(List<SimInput> inputs, {required int planTotal}) {
  final lines = <SimLine>[];
  for (final i in inputs) {
    final raw = i.mode == ReductionMode.percent ? i.plan * i.value ~/ 100 : i.value;
    lines.add(SimLine(i.key, i.plan, raw.clamp(0, i.plan < 0 ? 0 : i.plan)));
  }
  return SimResult(lines, planTotal);
}
