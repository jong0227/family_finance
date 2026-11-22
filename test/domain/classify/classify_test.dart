import 'package:family_finance/domain/classify/classify.dart';
import 'package:flutter_test/flutter_test.dart';

// 가짜 규칙·가짜 거래만 쓴다. (CLAUDE.md 절대 규칙 1)
ClassifyInput tx({
  String date = '2026-03-10',
  String type = 'expense',
  int amount = -10000,
  String? major,
  String? minor,
  String? merchant,
  String? payment,
  String? memo,
  List<String> tags = const [],
}) =>
    ClassifyInput(
      date: date, type: type, amount: amount, major: major, minor: minor,
      merchant: merchant, payment: payment, memo: memo, tags: tags,
    );

RuleSet set(List<Map<String, Object?>> rules, {String consumption = 'spend'}) =>
    RuleCodec.decode({'v': 1, 'consumptionKind': consumption, 'rules': rules});

Map<String, Object?> r(String id, Map<String, Object?> when, Map<String, Object?> then, {bool override = false}) =>
    {'id': id, 'when': when, 'then': then, if (override) 'override': true};

Classification run(ClassifyInput t, List<Map<String, Object?>> rules) => classifyTx(t, set(rules));

void main() {
  group('조건 종류', () {
    test('type · major · minor (문자열 또는 목록)', () {
      final rules = [
        r('a', {'type': 'income', 'major': ['급여A', '급여B']}, {'kind': 'salary'}),
        r('b', {'minor': 'OTT'}, {'kind': 'sub'}),
      ];
      expect(run(tx(type: 'income', major: '급여B'), rules).kind, 'salary');
      expect(run(tx(type: 'expense', major: '급여B'), rules).kind, isNull);
      expect(run(tx(minor: 'OTT'), rules).kind, 'sub');
    });

    test('merchantEquals / Contains / StartsWith / Regex', () {
      final rules = [
        r('eq', {'merchantEquals': '가나다카드'}, {'kind': 'card'}),
        r('has', {'merchantContains': ['OTT-A', 'OTT-B']}, {'kind': 'sub'}),
        r('st', {'merchantStartsWith': '국세'}, {'kind': 'tax'}),
        r('re', {'merchantRegex': r'^적금\d{2}-\d{3}$'}, {'kind': 'saving'}),
      ];
      expect(run(tx(merchant: '가나다카드'), rules).kind, 'card');
      expect(run(tx(merchant: '가나다카드(주)'), rules).kind, isNull);
      expect(run(tx(merchant: '월 OTT-B 결제'), rules).kind, 'sub');
      expect(run(tx(merchant: '국세청'), rules).kind, 'tax');
      expect(run(tx(merchant: '세금 국세'), rules).kind, isNull);
      expect(run(tx(merchant: '적금12-345'), rules).kind, 'saving');
      expect(run(tx(merchant: '적금12-3456'), rules).kind, isNull);
    });

    test('null 문자열은 빈 문자열로 본다 / 대소문자 구분', () {
      final rules = [
        r('e', {'merchantEquals': ''}, {'kind': 'empty'}),
      ];
      expect(run(tx(), rules).kind, 'empty');
      expect(run(tx(merchant: 'x'), [r('c', {'merchantContains': 'ABC'}, {'kind': 'k'})]).kind, isNull);
      expect(run(tx(merchant: 'abc'), [r('c', {'merchantContains': 'ABC'}, {'kind': 'k'})]).kind, isNull);
    });

    test('payment · memo · accountId · cardId', () {
      final rules = [
        r('p1', {'paymentStartsWith': '['}, {'kind': 'bank'}),
        r('p2', {'paymentIn': ['생활비 통장']}, {'kind': 'living-acct'}),
        r('p3', {'paymentContains': '가나다'}, {'kind': 'gnd'}),
        r('m', {'memoContains': '선물'}, {'kind': 'gift'}),
        r('a', {'accountId': 'acct_1'}, {'kind': 'acc'}),
        r('c', {'cardId': 'card_1'}, {'kind': 'crd'}),
      ];
      expect(run(tx(payment: '[가나다은행] 123'), rules).kind, 'bank');
      expect(run(tx(payment: '생활비 통장'), rules).kind, 'living-acct');
      expect(run(tx(payment: '가나다카드'), rules).kind, 'gnd');
      expect(run(tx(memo: '친구 선물'), rules).kind, 'gift');
      expect(classifyTx(const ClassifyInput(date: '2026-01-01', type: 'expense', amount: -1, accountId: 'acct_1'), set(rules)).kind, 'acc');
      expect(classifyTx(const ClassifyInput(date: '2026-01-01', type: 'expense', amount: -1, cardId: 'card_1'), set(rules)).kind, 'crd');
    });

    test('금액: 부호 있는 Eq/Min/Max, 절댓값 Eq/Min/Max, 경계 포함', () {
      List<Map<String, Object?>> one(Map<String, Object?> w) => [r('x', w, {'kind': 'hit'})];
      expect(run(tx(amount: -500), one({'amountEq': -500})).kind, 'hit');
      expect(run(tx(amount: 500), one({'amountEq': -500})).kind, isNull);
      expect(run(tx(amount: 1), one({'amountMin': 1})).kind, 'hit');
      expect(run(tx(amount: 0), one({'amountMin': 1})).kind, isNull);
      expect(run(tx(amount: -1), one({'amountMax': -1})).kind, 'hit');
      expect(run(tx(amount: -500), one({'amountAbsEq': 500})).kind, 'hit');
      expect(run(tx(amount: 500), one({'amountAbsEq': 500})).kind, 'hit');
      expect(run(tx(amount: -1000000), one({'amountAbsMin': 1000000})).kind, 'hit');
      expect(run(tx(amount: -999999), one({'amountAbsMin': 1000000})).kind, isNull);
      expect(run(tx(amount: 300), one({'amountAbsMax': 300})).kind, 'hit');
      expect(run(tx(amount: -301), one({'amountAbsMax': 300})).kind, isNull);
    });

    test('날짜 범위(경계 포함) · 일(day)', () {
      final w = {'dateFrom': '2026-03-01', 'dateTo': '2026-03-31'};
      List<Map<String, Object?>> one(Map<String, Object?> w) => [r('x', w, {'kind': 'hit'})];
      expect(run(tx(date: '2026-03-01'), one(w)).kind, 'hit');
      expect(run(tx(date: '2026-03-31'), one(w)).kind, 'hit');
      expect(run(tx(date: '2026-04-01'), one(w)).kind, isNull);
      expect(run(tx(date: '2026-02-28'), one(w)).kind, isNull);
      final d = one({'dayOfMonth': {'from': 20, 'to': 22}});
      expect(run(tx(date: '2026-05-21'), d).kind, 'hit');
      expect(run(tx(date: '2026-05-23'), d).kind, isNull);
    });

    test('tag · anyOf · not', () {
      final rules = [
        r('t', {'tag': 'fresh'}, {'kind': 'tagged'}),
        r('o', {'anyOf': [{'major': 'A'}, {'minor': 'B'}]}, {'kind': 'either'}),
        r('n', {'not': {'type': ['income', 'transfer']}}, {'kind': 'expense-path'}),
      ];
      expect(run(tx(tags: ['fresh']), rules).kind, 'tagged');
      expect(run(tx(minor: 'B'), rules).kind, 'either');
      expect(run(tx(), rules).kind, 'expense-path');
      expect(run(tx(type: 'income'), rules).kind, isNull);
    });

    test('조건 여러 개는 AND', () {
      final rules = [r('x', {'type': 'expense', 'merchantContains': 'OTT-A', 'amountMax': -1}, {'kind': 'k'})];
      expect(run(tx(merchant: 'OTT-A'), rules).kind, 'k');
      expect(run(tx(merchant: 'OTT-A', amount: 5), rules).kind, isNull);
      expect(run(tx(merchant: 'OTT-A', type: 'income'), rules).kind, isNull);
    });
  });

  group('순서·덮어쓰기·묶음', () {
    test('먼저 채운 일반 규칙이 이긴다', () {
      final rules = [
        r('1', {'merchantContains': '마트'}, {'categoryId': 'food'}),
        r('2', {'merchantContains': '가나다마트'}, {'categoryId': 'other'}),
      ];
      final out = run(tx(merchant: '가나다마트'), rules);
      expect(out.categoryId, 'food');
      expect(out.ruleIds, ['1']);
      final swapped = run(tx(merchant: '가나다마트'), rules.reversed.toList());
      expect(swapped.categoryId, 'other');
    });

    test('필드는 따로 채운다(kind 는 1번, 분류는 2번 규칙)', () {
      final out = run(tx(merchant: 'OTT-A'), [
        r('1', {'merchantContains': 'OTT'}, {'kind': 'spend'}),
        r('2', {'kind': 'spend', 'merchantContains': 'OTT-A'}, {'categoryId': 'sub'}),
      ]);
      expect((out.kind, out.categoryId), ('spend', 'sub'));
    });

    test('override 는 일반 규칙 값을 덮고, override 끼리는 먼저 쓴 쪽이 이긴다', () {
      final rules = [
        r('base', {}, {'kind': 'spend', 'categoryId': 'etc'}),
        r('o1', {'merchantContains': 'OTT-A'}, {'categoryId': 'sub'}, override: true),
        r('o2', {'merchantContains': 'OTT-A'}, {'categoryId': 'late'}, override: true),
      ];
      final out = run(tx(merchant: 'OTT-A'), rules);
      expect(out.categoryId, 'sub');
      expect(out.kind, 'spend');
      expect(out.ruleIds, ['base', 'o1']);
    });

    test('kind 가 있는 규칙은 묶음 — kind 를 못 채우면 분류도 새지 않는다', () {
      final out = run(tx(major: '이체'), [
        r('1', {'major': '이체'}, {'kind': 'ownTransfer'}),
        r('2', {'major': '이체'}, {'kind': 'spend', 'categoryId': 'leak'}),
      ]);
      expect((out.kind, out.categoryId), ('ownTransfer', null));
    });

    test('null 로 확정하면 이후 규칙이 못 채운다', () {
      final out = run(tx(), [
        r('o', {}, {'kind': 'proxy', 'categoryId': null}, override: true),
        r('b', {}, {'kind': 'spend', 'categoryId': 'etc'}),
        r('c', {'kind': 'proxy'}, {'categoryId': 'x'}),
      ]);
      expect((out.kind, out.categoryId), ('proxy', null));
    });

    test('앞선 결과를 보는 조건(kind·categoryId·oneOff)과 일회성·생활비 흐름', () {
      final rules = [
        r('k', {}, {'kind': 'spend'}),
        r('c', {'kind': 'spend', 'merchantContains': '식당'}, {'categoryId': 'eat'}),
        r('c2', {'kind': 'spend'}, {'categoryId': 'etc'}),
        r('big', {'kind': 'spend', 'amountAbsMin': 1000000, 'not': {'categoryId': ['rent']}}, {'oneOff': true}),
        r('liv', {'kind': 'spend', 'oneOff': false, 'categoryId': 'eat'}, {'living': 'dining'}),
      ];
      final small = run(tx(merchant: '식당', amount: -20000), rules);
      expect((small.categoryId, small.oneOff, small.living), ('eat', false, 'dining'));
      final big = run(tx(merchant: '식당', amount: -2000000), rules);
      expect((big.oneOff, big.living), (true, null));
    });

    test('enabled:false 규칙은 건너뛴다', () {
      final rs = RuleCodec.decode({
        'v': 1,
        'rules': [
          {'id': 'x', 'enabled': false, 'when': {}, 'then': {'kind': 'k'}},
        ],
      });
      expect(classifyTx(tx(), rs).kind, isNull);
    });

    test('priority 가 큰 규칙이 앞선다(같으면 목록 순서)', () {
      final rs = RuleCodec.decode({
        'v': 1,
        'rules': [
          {'id': 'low', 'when': {}, 'then': {'kind': 'low'}},
          {'id': 'high', 'priority': 700, 'when': {}, 'then': {'kind': 'high'}},
        ],
      });
      expect(rs.rules.first.id, 'high');
      expect(classifyTx(tx(), rs).kind, 'high');
    });
  });

  group('JSON', () {
    test('encode -> decode 왕복이 같은 결과를 낸다', () {
      final src = set([
        r('a', {'merchantRegex': r'^OTT-\d$', 'dayOfMonth': {'from': 1, 'to': 5}, 'anyOf': [{'major': 'x'}]}, {'kind': 'k', 'living': null}, override: true),
        r('b', {'dateFrom': '2026-01-01', 'amountAbsMin': 5}, {'oneOff': true}),
      ]);
      final again = RuleCodec.decode(RuleCodec.encode(src));
      expect(RuleCodec.encode(again), RuleCodec.encode(src));
    });

    test('모르는 키·잘못된 값은 거부한다', () {
      void bad(Map<String, Object?> j) => expect(() => RuleCodec.decode(j), throwsFormatException);
      bad({'v': 2, 'rules': []});
      bad({'v': 1, 'rules': [{'id': 'a', 'when': {'merchantContain': 'x'}, 'then': {'kind': 'k'}}]});
      bad({'v': 1, 'rules': [{'id': 'a', 'when': {}, 'then': {'color': 'red'}}]});
      bad({'v': 1, 'rules': [{'id': 'a', 'when': {}, 'then': {}}]});
      bad({'v': 1, 'rules': [{'id': 'a', 'when': {'amountMin': '5'}, 'then': {'kind': 'k'}}]});
      bad({'v': 1, 'rules': [{'id': 'a', 'when': {'dateFrom': '2026/01/01'}, 'then': {'kind': 'k'}}]});
      bad({'v': 1, 'rules': [{'id': 'a', 'when': {'merchantRegex': '('}, 'then': {'kind': 'k'}}]});
      bad({'v': 1, 'rules': [
        {'id': 'a', 'when': {}, 'then': {'kind': 'k'}},
        {'id': 'a', 'when': {}, 'then': {'kind': 'k'}},
      ]});
    });
  });

  group('총액 보존 불변식', () {
    test('분류·일회성·생활비가 어떻게 갈려도 거래 합은 그대로다', () {
      final rules = set([
        r('card', {'merchantContains': '가나다카드'}, {'kind': 'cardPayment'}),
        r('own', {'major': '내계좌이체'}, {'kind': 'ownTransfer'}),
        r('inc', {'type': 'income'}, {'kind': 'income'}),
        r('sp', {'not': {'type': ['income', 'transfer']}}, {'kind': 'spend'}),
        r('food', {'kind': 'spend', 'merchantContains': '식당'}, {'categoryId': 'eat'}),
        r('etc', {'kind': 'spend'}, {'categoryId': 'etc'}),
        r('big', {'kind': 'spend', 'amountAbsMin': 1000000}, {'oneOff': true}),
        r('liv', {'kind': 'spend', 'oneOff': false, 'categoryId': 'eat'}, {'living': 'dining'}),
      ]);
      final inputs = <ClassifyInput>[
        tx(date: '2026-03-02', merchant: '식당 A', amount: -12000),
        tx(date: '2026-03-03', merchant: '식당 B', amount: -1500000),
        tx(date: '2026-03-04', merchant: '가나다카드', amount: -300000, type: 'transfer'),
        tx(date: '2026-03-05', merchant: '월급', amount: 2500000, type: 'income'),
        tx(date: '2026-03-06', major: '내계좌이체', amount: -50000, type: 'transfer'),
        tx(date: '2026-04-01', merchant: '문구점', amount: -3000),
        tx(date: '2026-04-02', merchant: '환불', amount: 3000, type: 'income'),
        tx(date: '2026-04-03', merchant: '해외 결제', amount: -777, type: 'weird'),
      ];
      final rows = [
        for (final t in inputs) (month: t.date.substring(0, 7), amount: t.amount, cls: classifyTx(t, rules)),
      ];
      final agg = aggregateMonths(rows, consumptionKind: rules.consumptionKind);

      expect(agg.values.fold<int>(0, (a, m) => a + m.net), inputs.fold<int>(0, (a, t) => a + t.amount));
      expect(agg.values.fold<int>(0, (a, m) => a + m.txCount), inputs.length);
      for (final m in agg.values) {
        expect(m.consumption, m.regular + m.oneOff);
        expect(m.consumption, m.byCategory.values.fold<int>(0, (a, b) => a + b));
        expect(m.regular, m.byCategoryRegular.values.fold<int>(0, (a, b) => a + b));
        expect(m.livingTotal, lessThanOrEqualTo(m.regular));
      }
      final march = agg['2026-03']!;
      expect((march.consumption, march.oneOff, march.regular, march.livingTotal), (1512000, 1500000, 12000, 12000));
    });
  });
}
