import 'classify_engine.dart';

/// 월 집계 (`months/{YYYY-MM}` 의 소비 관련 숫자). 총액 보존: 모든 거래가 byKind 에 한 번씩 들어간다.
class MonthTotals {
  int txCount = 0;
  int consumption = 0, oneOff = 0, regular = 0;
  final byCategory = <String, int>{};
  final byCategoryRegular = <String, int>{};
  final living = <String, int>{};

  /// kind -> (inflow: 양수 합, outflow: 음수 합의 절댓값). 분류 못 한 거래는 키 `''`.
  final byKind = <String, ({int inflow, int outflow})>{};

  int get livingTotal => living.values.fold(0, (a, b) => a + b);

  /// 모든 거래의 부호 있는 합 — 입력 합과 같아야 한다.
  int get net => byKind.values.fold(0, (a, k) => a + k.inflow - k.outflow);
}

/// 거래(월, 금액, 분류) 목록을 월별로 집계한다. 소비 = [consumptionKind] 인 거래의 -금액.
Map<String, MonthTotals> aggregateMonths(
  Iterable<({String month, int amount, Classification cls})> txs, {
  required String consumptionKind,
}) {
  final out = <String, MonthTotals>{};
  for (final t in txs) {
    final m = out.putIfAbsent(t.month, MonthTotals.new);
    m.txCount++;
    final kind = t.cls.kind ?? '';
    final k = m.byKind[kind] ?? (inflow: 0, outflow: 0);
    m.byKind[kind] = t.amount >= 0
        ? (inflow: k.inflow + t.amount, outflow: k.outflow)
        : (inflow: k.inflow, outflow: k.outflow - t.amount);
    if (kind != consumptionKind) continue;
    final spent = -t.amount;
    m.consumption += spent;
    final cat = t.cls.categoryId ?? '';
    m.byCategory[cat] = (m.byCategory[cat] ?? 0) + spent;
    if (t.cls.oneOff) {
      m.oneOff += spent;
    } else {
      m.regular += spent;
      m.byCategoryRegular[cat] = (m.byCategoryRegular[cat] ?? 0) + spent;
      final lv = t.cls.living;
      if (lv != null) m.living[lv] = (m.living[lv] ?? 0) + spent;
    }
  }
  return out;
}
