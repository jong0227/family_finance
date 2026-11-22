import 'package:family_finance/domain/cash_check.dart';
import 'package:family_finance/domain/diagnosis.dart';
import 'package:family_finance/domain/finance_models.dart';
import 'package:family_finance/domain/month_report.dart';
import 'package:family_finance/domain/pay_day.dart';
import 'package:family_finance/domain/timeline.dart';
import 'package:family_finance/domain/tx_note.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _item(String id, int amount,
        {String? account, String payment = '', String? payDay, String? note, String? living, String? card}) =>
    {
      'id': id,
      'name': '항목$id',
      'monthlyAmount': amount,
      'accountId': account,
      'cardId': card,
      'payment': payment,
      'payDayText': payDay,
      'note': note,
      'living': living,
    };

Plan _plan(List<Map<String, Object?>> items, {String group = '생활비'}) => Plan.fromJson({
      'groups': [
        {
          'name': group,
          'categories': [
            {'name': '분류', 'items': items},
          ],
        },
      ],
    }, {'a1': '생활비 통장', 'a2': '월급 통장'});

void main() {
  cardTests();
  group('결제일 해석', () {
    test('흔한 문구', () {
      expect(parsePayDay('매월 21일'), const PayDay.day(21));
      expect(parsePayDay('21'), const PayDay.day(21));
      expect(parsePayDay('말일'), const PayDay.last());
      expect(parsePayDay('매월 말일'), const PayDay.last());
    });
    test('모르면 null — 추측하지 않는다', () {
      for (final t in [null, '', '  ', '매주 월요일', '3월 15일', '5일, 20일', '40일', '0일', '수시']) {
        expect(parsePayDay(t), isNull, reason: '$t');
      }
    });
    test('주말은 다음 월요일, 짧은 달은 말일', () {
      // 2026-11-21 은 토요일 → 11-23(월)
      expect(payDateIn('2026-11', const PayDay.day(21)), DateTime(2026, 11, 23));
      expect(payDateIn('2026-11', const PayDay.day(20)), DateTime(2026, 11, 20));
      expect(payDateIn('2026-02', const PayDay.day(31)), DateTime(2026, 3, 2)); // 28일(토) → 월요일
        });
    test('말일', () {
      expect(payDateIn('2026-12', const PayDay.last()), DateTime(2026, 12, 31));
      expect(payDateIn('bad', const PayDay.last()), isNull);
    });
  });

  group('현금 점검', () {
    const cards = {'c1': CardRef(id: 'c1', nickname: '가나다카드', payDay: 21, withdrawalAccountId: 'a1')};
    final plan = _plan([
      _item('1', 800000, account: 'a1', payment: '가나다카드', payDay: '매월 5일', card: 'c1'),
      _item('2', 400000, account: 'a1', payment: '가나다카드', payDay: '매월 5일', card: 'c1'),
      _item('3', 300000, account: 'a1', payDay: '5일'),
      _item('4', 200000, account: 'a1'), // 날짜 미정
      _item('5', 500000, account: 'a2', payDay: '말일'),
      _item('6', 100000), // 통장 없음
      _item('7', 0, account: 'a2'),
    ]);

    test('카드 항목은 한 줄로 합치고 날짜 순, 미정은 맨 뒤', () {
      final r = computeCashCheck(month: '2026-11', plan: plan, balances: {'a1': 1000000}, cards: cards, accountNames: {'a1': '생활비 통장'});
      final a1 = r.accounts.firstWhere((a) => a.accountId == 'a1');
      expect(a1.name, '생활비 통장');
      expect(a1.outflows.length, 3);
      expect(a1.outflows[1].name, contains('항목 2개'));
      expect(a1.outflows[1].amount, 1200000);
      expect(a1.outflows.last.date, isNull);
      expect(a1.cardTotal, 1200000);
      expect(a1.datedTotal, 1500000);
      expect(a1.undatedTotal, 200000);
      expect(a1.total, 1700000);
      expect(r.unassigned.map((i) => i.id), ['6']);
    });

    test('부족액 계산', () {
      final r = computeCashCheck(month: '2026-11', plan: plan, balances: {'a1': 1000000, 'a2': 900000}, cards: cards);
      final a1 = r.accounts.firstWhere((a) => a.accountId == 'a1');
      expect(a1.shortfall, 500000);
      expect(a1.shortfallWithUndated, 700000);
      // 5일(300k) 후 700k, 23일 카드 1.2M 에서 모자람
      expect(a1.firstShortDate, DateTime(2026, 11, 23));
      final a2 = r.accounts.firstWhere((a) => a.accountId == 'a2');
      expect(a2.shortfall, 0);
      expect(a2.spare, 400000);
      expect(r.shortfallTotal, 500000);
    });

    test('잔액 미입력은 부족 계산에서 빠지고, 제외 통장은 여유로 안 친다', () {
      final r = computeCashCheck(month: '2026-11', plan: plan, balances: {'a2': 900000}, excluded: {'a2'}, cards: cards);
      final a1 = r.accounts.firstWhere((a) => a.accountId == 'a1');
      expect(a1.shortfall, isNull);
      expect(r.missingBalanceCount, 1);
      expect(r.shortfallTotal, 0);
      expect(r.spareTotal, 0);
    });
  });

  group('타임라인', () {
    test('회차 표기가 있는 할부만 남은 회차·끝나는 달 계산', () {
      final plan = _plan([
        _item('1', 120000, note: '가전 3/10회'),
        _item('2', 50000, note: '할부 중'),
        _item('3', 500000),
        _item('4', 500000, living: '배달'),
        _item('5', 100000),
      ]);
      final t = buildTimeline(plan: plan, from: '2026-11', months: 3);
      expect(t.map((m) => m.month), ['2026-11', '2026-12', '2027-01']);
      final first = t.first.entries;
      expect(first.map((e) => e.kind),
          containsAll([TimelineKind.installment, TimelineKind.installmentUnknown, TimelineKind.large]));
      expect(first.length, 3); // 생활비 묶음·소액은 제외
      final inst = first.firstWhere((e) => e.kind == TimelineKind.installment);
      expect(inst.remaining, 7);
      expect(inst.endMonth, '2027-06');
    });
    test('할부가 끝난 달에는 빠진다', () {
      final plan = _plan([_item('1', 100000, note: '9/10회')]);
      final t = buildTimeline(plan: plan, from: '2026-11', months: 3);
      expect(t[0].entries.length, 1);
      expect(t[1].entries.length, 1);
      expect(t[2].entries, isEmpty);
    });
    test('회차 파싱·월 더하기', () {
      expect(parseInstallment('12/6회'), isNull);
      expect(parseInstallment('없음'), isNull);
      expect(addMonths('2026-11', 3), '2027-02');
      expect(addMonths('2026-01', -1), '2025-12');
    });
  });

  group('월말 리포트 집계', () {
    final plan = _plan([
      _item('1', 100000, living: '배달'),
      _item('2', 200000, living: '간식'),
      _item('3', 300000),
    ]);
    Tx tx(String k, String merchant, int amount, {bool oneOff = false, String kind = '소비', String date = '2026-10-05'}) =>
        Tx(key: k, date: date, time: '10:00', merchant: merchant, amount: amount, kind: kind, category: '', payment: '', oneOff: oneOff);
    final agg = const MonthAgg(
      month: '2026-10',
      consumption: 900000,
      regular: 700000,
      oneOff: 200000,
      byCategoryRegular: {},
      living: {'배달': 150000, '간식': 150000},
      partial: false,
      coveredUntil: null,
    );

    test('계획 대비·생활비 초과/여유·가맹점·일회성', () {
      final r = buildMonthReport(
        month: '2026-10',
        agg: agg,
        plan: plan,
        txs: [
          tx('1', '가게A', -30000),
          tx('2', '가게A', -20000),
          tx('3', '가게B', -40000),
          tx('4', '큰결제', -200000, oneOff: true),
          tx('5', '환급', 10000),
          tx('6', '이체', -999, kind: '이체'),
          tx('7', '가게C', -5000, date: '2026-09-30'),
        ],
        diagnosis: const DiagnosisResult([]),
      );
      expect(r.planTotal, 600000);
      expect(r.diff, 300000);
      expect(r.livingOver, 50000);
      expect(r.livingUnder, 50000);
      expect(r.living.first.group, '배달');
      expect(r.topMerchants.map((m) => m.name), ['가게A', '가게B']);
      expect(r.topMerchants.first.amount, 50000);
      expect(r.topMerchants.first.count, 2);
      expect(r.oneOffs.length, 1);
      expect(r.oneOffTotal, 200000);
    });

    test('저축 구분은 계획 합계에서 뺀다', () {
      final p = Plan.fromJson({
        'groups': [
          {'name': '저축', 'categories': [{'name': 'x', 'items': [_item('1', 400000)]}]},
          {'name': '생활비', 'categories': [{'name': 'y', 'items': [_item('2', 100000)]}]},
        ],
      }, const {});
      final r = buildMonthReport(month: '2026-10', agg: null, plan: p, txs: const []);
      expect(r.planTotal, 100000);
      expect(r.consumption, 0);
    });
  });

  group('메모·태그', () {
    test('payload 키는 note·userTags·noteBy 뿐 (src·cls 없음)', () {
      final m = notePayload(note: ' 생일 선물 ', tags: ['#선물', ' 선물 ', '', '환불'], by: 'u1');
      expect(m.keys.toSet(), {'note', 'userTags', 'noteBy'});
      expect(m['note'], '생일 선물');
      expect(m['userTags'], ['선물', '환불']);
      expect(m['noteBy'], 'u1');
    });
    test('작성자가 없으면 noteBy 키 자체를 뺀다', () {
      expect(notePayload(note: '', tags: const [], by: null).keys.toSet(), {'note', 'userTags'});
    });
    test('태그 한도', () {
      expect(normalizeTags(List.generate(20, (i) => 't$i')).length, kTagMaxCount);
      expect(normalizeTags(['a' * 50]).single.length, kTagMaxLen);
      expect(parseTagInput('a, b  c,,#d'), ['a', 'b', 'c', 'd']);
    });
    test('Tx.fromJson 은 note·userTags·noteBy 를 읽고 없으면 비어 있다', () {
      final t = Tx.fromJson('k', {'src': {'date': '2026-10-01'}, 'note': '메모', 'userTags': ['a', 3, 'b'], 'noteBy': 'u'});
      expect(t.note, '메모');
      expect(t.userTags, ['a', 'b']);
      expect(t.noteBy, 'u');
      final e = Tx.fromJson('k', {});
      expect(e.note, '');
      expect(e.userTags, isEmpty);
    });
  });
}

void cardTests() {
  group('카드 결제일 기준', () {
    const cards = {
      'c1': CardRef(id: 'c1', nickname: '가나다카드', payDay: 21, withdrawalAccountId: 'a2'),
      'c2': CardRef(id: 'c2', nickname: '라마바카드', withdrawalAccountId: 'a1'), // 결제일 모름
    };
    test('카드 항목은 카드의 출금 통장·결제일을 쓰고 항목 결제일 문구는 무시', () {
      final plan = _plan([
        _item('1', 100000, account: 'a1', payDay: '5일', card: 'c1'),
        _item('2', 50000, account: 'a1', payDay: '7일', card: 'c1'),
      ]);
      final r = computeCashCheck(month: '2026-11', plan: plan, balances: const {}, cards: cards);
      expect(r.accounts.length, 1);
      final a = r.accounts.single;
      expect(a.accountId, 'a2'); // 항목 통장(a1)이 아니라 카드 출금 통장
      expect(a.outflows.single.name, contains('가나다카드'));
      expect(a.outflows.single.name, contains('항목 2개'));
      expect(a.outflows.single.amount, 150000);
      expect(a.outflows.single.date, DateTime(2026, 11, 23)); // 21일(토) → 월요일
    });
    test('카드 결제일이 없으면 날짜 미정, 출금 통장 없으면 항목 통장', () {
      final plan = _plan([
        _item('1', 100000, account: 'a2', payDay: '5일', card: 'c2'),
        _item('2', 70000, account: 'a2', card: 'cX'), // 모르는 카드
      ]);
      final r = computeCashCheck(month: '2026-11', plan: plan, balances: const {}, cards: cards);
      final a1 = r.accounts.firstWhere((a) => a.accountId == 'a1');
      expect(a1.outflows.single.date, isNull);
      final a2 = r.accounts.firstWhere((a) => a.accountId == 'a2');
      expect(a2.outflows.single.date, isNull);
      expect(a2.undatedTotal, 70000);
    });
    test('cardId 없이 payment 에 카드가 있으면 항목 통장 아래 날짜 미정 카드 줄', () {
      final plan = _plan([
        _item('1', 30000, account: 'a1', payment: '마바사카드', payDay: '10일'),
        _item('2', 20000, account: 'a1', payment: '마바사카드', payDay: '15일'),
      ]);
      final a = computeCashCheck(month: '2026-11', plan: plan, balances: const {}).accounts.single;
      expect(a.outflows.single.isCard, isTrue);
      expect(a.outflows.single.amount, 50000);
      expect(a.outflows.single.date, isNull);
    });
    test('생활비 항목도 포함하고 줄에 계획 기준 추정 표시', () {
      final plan = _plan([
        _item('1', 100000, account: 'a1', card: 'c1', living: '배달'),
        _item('2', 40000, account: 'a1', card: 'c1'),
      ]);
      final a = computeCashCheck(month: '2026-11', plan: plan, balances: const {}, cards: cards).accounts.single;
      expect(a.outflows.single.amount, 140000);
      expect(a.outflows.single.name, contains('계획 기준 추정'));
    });
  });
}
