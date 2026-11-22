import 'package:family_finance/domain/diagnosis.dart';
import 'package:family_finance/domain/finance_models.dart';
import 'package:family_finance/domain/kid_spending.dart';
import 'package:family_finance/domain/savings_simulator.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실제 데이터 모양: 월 집계의 지출 분류(byCategoryRegular)는 계획 분류와 이름 체계가 다르다.
/// 월별 실제는 생활비 묶음(living)에만 있고, 나머지 계획 항목은 recentActual 한 값뿐이다.
Plan _plan() {
  Map<String, Object?> item(String id, int amount, {String? living, int? recent}) =>
      {'id': id, 'name': '항목$id', 'monthlyAmount': amount, 'living': living, 'recentActual': recent, 'payment': ''};
  return Plan.fromJson({
    'groups': [
      {
        'name': '생활비',
        'categories': [
          {'name': '분류가', 'items': [item('a', 100000, living: '배달'), item('b', 200000, recent: 300000)]},
          {'name': '분류나', 'items': [item('c', 100000, recent: 50000), item('d', 80000), item('e', 90000, recent: 91000)]},
        ],
      },
      {
        'name': '대출',
        'categories': [
          {'name': '분류고정', 'items': [item('f', 500000, recent: 900000)]},
        ],
      },
    ],
  }, const {});
}

MonthAgg _m(String month, {int delivery = 150000, bool partial = false}) => MonthAgg(
      month: month,
      consumption: 0,
      regular: 0,
      oneOff: 0,
      // 계획 분류와 겹치지 않는 지출 분류 키(회귀: 이걸로 계획을 비교하면 안 됨).
      byCategoryRegular: const {'지출분류X': 999999999, '지출분류Y': 1},
      living: {'배달': delivery},
      partial: partial,
      coveredUntil: null,
    );

Tx _tx(String date, int amount, String living, {String merchant = '가게', String minor = '', bool oneOff = false}) => Tx(
      key: '$date$amount$merchant',
      date: date,
      time: '12:00',
      merchant: merchant,
      amount: amount,
      kind: '소비',
      category: '지출분류X',
      payment: '카드',
      oneOff: oneOff,
      minor: minor,
      living: living,
    );

void main() {
  group('진단', () {
    final months = [
      for (var i = 1; i <= 6; i++) _m('2026-0$i', delivery: i <= 5 ? 150000 : 90000),
      _m('2026-07', delivery: 9000000, partial: true),
    ];
    final r = diagnose(plan: _plan(), months: months);

    test('생활비 묶음: 6개월 중 5개월 초과 = 줄일 것, 근거 문구', () {
      final row = r.cut.firstWhere((x) => x.scope == DiagnosisScope.living);
      expect(row.key, '배달');
      expect(row.overMonths, 5);
      expect(row.evidence, '최근 6개월 중 5개월 초과 · 2026-01~2026-06');
      expect(row.months.contains('2026-07'), isFalse);
    });

    test('지출 분류 키(byCategoryRegular)는 비교에 쓰지 않는다', () {
      expect(r.rows.any((x) => x.key.startsWith('지출분류')), isFalse);
      expect(r.rows.any((x) => x.scope == DiagnosisScope.item && x.n > 0), isFalse);
    });

    test('계획 항목은 recentActual 한 값으로 비교, 근거는 "최근 실제 기준"', () {
      final over = r.cut.firstWhere((x) => x.key == 'b');
      expect(over.diff, 100000);
      expect(over.evidence, '최근 실제 기준');
      expect(r.slack.single.key, 'c');
      expect(r.slack.single.diff, -50000);
    });

    test('recentActual 이 없으면 빠지고, ±5% 안은 판정 없음', () {
      expect(r.rows.any((x) => x.key == 'd'), isFalse);
      expect(r.rows.firstWhere((x) => x.key == 'e').verdict, Verdict.ok);
    });

    test('대출·저축 구분은 줄일 것에서 빠지고 고정 묶음으로', () {
      expect(r.cut.any((x) => x.key == 'f'), isFalse);
      expect(r.fixed.single.key, 'f');
    });

    test('완전한 달이 3개월 미만이면 묶음은 판정 보류', () {
      final few = diagnose(plan: _plan(), months: months.take(2).toList());
      expect(few.rows.firstWhere((x) => x.key == '배달').verdict, Verdict.insufficient);
    });

    test('가끔만 초과하면 줄일 것이 아님', () {
      final mixed = [for (var i = 1; i <= 6; i++) _m('2026-0$i', delivery: i.isEven ? 200000 : 100000)];
      final res = diagnose(plan: _plan(), months: mixed);
      expect(res.rows.firstWhere((x) => x.key == '배달').verdict, Verdict.ok);
    });
  });

  group('아이별', () {
    final txs = [
      _tx('2026-01-05', -30000, '간식', minor: ''),
      _tx('2026-02-05', -50000, '간식'),
      _tx('2026-03-05', -70000, '간식'), // 진행 중인 달
      _tx('2026-01-06', -999, '배달', oneOff: true), // 일회성 제외
    ];
    final months = [_m('2026-01'), _m('2026-02'), _m('2026-03', partial: true)];

    test('생활비 구성은 월별 실제, 진행 중인 달은 평균에서 제외', () {
      final part = txs.first.livingPart;
      expect(livingPartNames(txs), [part]);
      final ks = kidSpending(plan: _plan(), months: months, livingTx: txs, selected: {kidPartKey(part)});
      final row = ks.parts.single;
      expect(row.months.map((m) => m.amount), [30000, 50000, 70000]);
      expect(row.average, 40000);
    });

    test('계획 분류는 항목 계획·최근 실제', () {
      final ks = kidSpending(plan: _plan(), months: months, livingTx: txs, selected: {kidCategoryKey('분류나')});
      final c = ks.categories.single;
      expect(c.plan, 270000);
      expect(c.recentActual, 141000);
      expect(ks.parts, isEmpty);
    });

    test('아무것도 안 고르면 비어 있다', () {
      expect(kidSpending(plan: _plan(), months: months, livingTx: txs, selected: const {}).isEmpty, isTrue);
    });
  });

  group('절감 시뮬레이터', () {
    test('비율·금액 합산과 연 환산, 계획 초과 절감은 잘라 냄', () {
      final r = simulateSavings([
        const SimInput(key: 'a', plan: 300000, mode: ReductionMode.percent, value: 10),
        const SimInput(key: 'b', plan: 100000, mode: ReductionMode.amount, value: 150000),
      ], planTotal: 1000000);
      expect(r.monthly, 130000);
      expect(r.annual, 1560000);
      expect(r.newPlanTotal, 870000);
      expect(r.shareOfPlan, closeTo(0.13, 1e-9));
    });
  });
}
