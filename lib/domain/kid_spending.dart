/// S7 아이별 지출 — 사용자가 고른 계획 분류(사용자 분류 체계)와 생활비 구성(livingPart)의 지출. Flutter·Firebase 를 모른다.
/// 월별 실제는 거래의 생활비 구성에서만 나온다. 계획 분류는 항목의 계획·최근 실제 한 값만 있다.
library;

import 'finance_models.dart';

/// 선택 키: 계획 분류는 `c:이름`, 생활비 구성은 `p:이름`.
String kidCategoryKey(String category) => 'c:$category';
String kidPartKey(String part) => 'p:$part';

/// 거래에 나온 생활비 구성 이름들(일회성 제외, 이름순).
List<String> livingPartNames(List<Tx> txs) =>
    ({for (final t in txs) if (!t.oneOff && t.living != null) t.livingPart}.toList()..sort());

class KidMonth {
  const KidMonth(this.month, this.amount, this.partial);
  final String month;
  final int amount;
  final bool partial;
}

/// 고른 계획 분류: 그 분류 계획 항목들.
class KidCategoryRow {
  const KidCategoryRow({required this.category, required this.plan, required this.items});
  final String category;
  final int plan;
  final List<PlanItem> items;

  /// 항목 `recentActual` 합(값이 있는 항목만). 하나도 없으면 null.
  int? get recentActual {
    final v = [for (final i in items) if (i.recentActual != null) i.recentActual!];
    return v.isEmpty ? null : v.fold<int>(0, (a, b) => a + b);
  }
}

/// 고른 생활비 구성: 최근 달별 지출.
class KidPartRow {
  const KidPartRow({required this.part, required this.months, required this.average});
  final String part;
  final List<KidMonth> months;

  /// 완전한 달만의 평균.
  final int average;
}

class KidSpending {
  const KidSpending({required this.categories, required this.parts});
  final List<KidCategoryRow> categories;
  final List<KidPartRow> parts;

  bool get isEmpty => categories.isEmpty && parts.isEmpty;
}

KidSpending kidSpending({
  required Plan plan,
  required List<MonthAgg> months,
  required List<Tx> livingTx,
  required Set<String> selected,
  int window = 6,
}) {
  final sorted = [...months]..sort((a, b) => a.month.compareTo(b.month));
  final win = sorted.length > window ? sorted.sublist(sorted.length - window) : sorted;

  final cats = <KidCategoryRow>[];
  final seen = <String>{};
  for (final i in plan.items) {
    if (!seen.add(i.category) || !selected.contains(kidCategoryKey(i.category))) continue;
    final items = plan.items.where((x) => x.category == i.category).toList();
    cats.add(KidCategoryRow(category: i.category, plan: items.fold(0, (a, x) => a + x.monthlyAmount), items: items));
  }

  final parts = <KidPartRow>[];
  for (final name in livingPartNames(livingTx)) {
    if (!selected.contains(kidPartKey(name))) continue;
    final byMonth = <String, int>{};
    for (final t in livingTx) {
      if (t.oneOff || t.living == null || t.livingPart != name) continue;
      byMonth[t.month] = (byMonth[t.month] ?? 0) - t.amount;
    }
    final ms = [for (final m in win) KidMonth(m.month, byMonth[m.month] ?? 0, m.partial)];
    final full = [for (final m in ms) if (!m.partial) m.amount];
    parts.add(KidPartRow(
      part: name,
      months: ms,
      average: full.isEmpty ? 0 : full.reduce((a, b) => a + b) ~/ full.length,
    ));
  }
  return KidSpending(categories: cats, parts: parts);
}
