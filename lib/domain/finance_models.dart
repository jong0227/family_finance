/// 가계 데이터 모델 (Flutter·Firebase 를 모른다). Firestore 문서 모양은 ARCHITECTURE 5.3.
library;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
Map<String, int> _intMap(Object? v) =>
    v is Map ? {for (final e in v.entries) e.key as String: _int(e.value)} : const {};

/// 생활비 7개 계획 항목을 비교 단위로 묶은 것. 아이·어른 구분이 가계부에 없어 간식·잡화는 둘을 합친다.
const livingGroups = ['잡화', '식료품·반찬', '외식·카페', '배달', '간식'];
const livingLabels = {
  '배달': '어른식비배달',
  '외식·카페': '카페외식',
  '식료품·반찬': '서채반찬비',
  '간식': '서채간식 + 어른간식',
  '잡화': '서채잡화 + 어른잡화',
};

/// 월 집계 문서 `months/{YYYY-MM}`.
class MonthAgg {
  const MonthAgg({
    required this.month,
    required this.consumption,
    required this.regular,
    required this.oneOff,
    required this.byCategoryRegular,
    required this.living,
    required this.partial,
    required this.coveredUntil,
  });

  final String month;
  final int consumption, regular, oneOff;
  final Map<String, int> byCategoryRegular, living;
  final bool partial;
  final String? coveredUntil;

  int get livingTotal => living.values.fold(0, (a, b) => a + b);

  factory MonthAgg.fromJson(Map<String, Object?> j) => MonthAgg(
        month: j['month'] as String,
        consumption: _int(j['consumption']),
        regular: _int(j['regular']),
        oneOff: _int(j['oneOff']),
        byCategoryRegular: _intMap(j['byCategoryRegular']),
        living: _intMap(j['living']),
        partial: j['partial'] == true,
        coveredUntil: j['coveredUntil'] as String?,
      );
}

/// 계획 항목 (구분 → 지출 분류 → 항목).
class PlanItem {
  const PlanItem({
    required this.id,
    required this.group,
    required this.category,
    required this.name,
    required this.monthlyAmount,
    required this.previousPlan,
    required this.recentActual,
    required this.payment,
    required this.accountName,
    required this.payDayText,
    required this.living,
    required this.note,
  });

  final String id, group, category, name;
  final int monthlyAmount, previousPlan;
  final int? recentActual;
  final String payment;
  final String? accountName, payDayText, living, note;
}

class Plan {
  const Plan(this.items);
  final List<PlanItem> items;

  int get total => items.fold(0, (a, i) => a + i.monthlyAmount);

  /// 생활비 비교 단위별 계획 금액.
  Map<String, int> get livingPlan {
    final m = <String, int>{};
    for (final i in items) {
      final g = i.living;
      if (g != null) m[g] = (m[g] ?? 0) + i.monthlyAmount;
    }
    return m;
  }

  int get livingPlanTotal => livingPlan.values.fold(0, (a, b) => a + b);

  factory Plan.fromJson(Map<String, Object?> j, Map<String, String> accountNames) {
    final items = <PlanItem>[];
    for (final g in (j['groups'] as List? ?? const [])) {
      final gm = g as Map;
      for (final c in (gm['categories'] as List? ?? const [])) {
        final cm = c as Map;
        for (final it in (cm['items'] as List? ?? const [])) {
          final im = (it as Map).cast<String, Object?>();
          if (im['deleted'] == true) continue;
          items.add(PlanItem(
            id: im['id'] as String,
            group: gm['name'] as String,
            category: cm['name'] as String,
            name: im['name'] as String,
            monthlyAmount: _int(im['monthlyAmount']),
            previousPlan: _int(im['previousPlan']),
            recentActual: (im['recentActual'] as num?)?.toInt(),
            payment: im['payment'] as String? ?? '',
            accountName: accountNames[im['accountId']],
            payDayText: im['payDayText'] as String?,
            living: im['living'] as String?,
            note: im['note'] as String?,
          ));
        }
      }
    }
    return Plan(items);
  }
}

/// 거래 `transactions/{key}` (화면에 필요한 것만).
class Tx {
  const Tx({
    required this.key,
    required this.date,
    required this.time,
    required this.merchant,
    required this.amount,
    required this.kind,
    required this.category,
    required this.payment,
    required this.oneOff,
    this.minor = '',
    this.living,
  });

  final String key, date, time, merchant, kind, category, payment;
  final String minor;
  final String? living;
  final int amount;
  final bool oneOff;

  String get sortKey => '$date $time';
  String get month => date.length >= 7 ? date.substring(0, 7) : '';

  /// 생활비 묶음 안에서 "무엇에 썼나" 구성 이름 (보고서와 같은 나눔).
  String get livingPart {
    switch (living) {
      case '잡화':
        if (category.startsWith('의류')) return '의류·백화점';
        if (category.startsWith('가정용품')) return '생활·가정용품';
        if (merchant.contains('내역 미확인') || merchant.startsWith('쿠팡(쿠페이)')) return '쿠팡 (내역 미확인)';
        return '쿠팡 (확인된 상품)';
      case '외식·카페':
        return minor == '커피/음료' ? '커피·카페' : '식당 외식';
      case '식료품·반찬':
        return merchant.startsWith('쿠팡') ? '쿠팡 식품' : '마트·장보기';
      case '배달':
        return '배달앱';
      case '간식':
        return '빵·아이스크림·디저트';
    }
    return category;
  }

  /// 가맹점 이름을 묶기 좋게 (쿠팡 상품명 앞머리 정리).
  String get merchantKey {
    if (merchant.contains('내역 미확인') || merchant.startsWith('쿠팡(쿠페이)')) return '쿠팡 (내역 미확인)';
    return merchant.replaceFirst('쿠팡 · ', '쿠팡 ');
  }

  factory Tx.fromJson(String key, Map<String, Object?> j) {
    final src = (j['src'] as Map? ?? const {}).cast<String, Object?>();
    final cls = (j['cls'] as Map? ?? const {}).cast<String, Object?>();
    return Tx(
      key: key,
      date: src['date'] as String? ?? '',
      time: src['time'] as String? ?? '',
      merchant: src['merchant'] as String? ?? '',
      amount: _int(src['amount']),
      kind: cls['kind'] as String? ?? '',
      category: cls['categoryId'] as String? ?? '',
      payment: src['payment'] as String? ?? '',
      oneOff: cls['oneOff'] == true,
      minor: src['minor'] as String? ?? '',
      living: cls['living'] as String?,
    );
  }
}
