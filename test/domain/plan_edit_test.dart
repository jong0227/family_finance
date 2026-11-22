import 'package:family_finance/domain/finance_models.dart';
import 'package:family_finance/domain/plan_edit.dart';
import 'package:flutter_test/flutter_test.dart';

PlanDoc _doc() => {
      'effectiveFrom': '2026-01',
      'groups': [
        {
          'name': '고정',
          'categories': [
            {
              'name': '통신',
              'items': [
                {'id': 'a', 'name': '항목A', 'monthlyAmount': 1000, 'previousPlan': 900, 'payment': '가나다카드', 'order': 0, 'deleted': false},
                {'id': 'b', 'name': '항목B', 'monthlyAmount': 2000, 'previousPlan': 0, 'payment': '', 'order': 1, 'deleted': false},
              ],
            },
            {'name': '비어있음', 'items': <Object?>[]},
          ],
        },
        {
          'name': '생활비',
          'categories': [
            {'name': '식비', 'items': <Object?>[]},
          ],
        },
      ],
    };

/// 메모리 저장소: 트랜잭션처럼 현재 값을 읽어 변환 후 저장.
class _MemStore implements PlanWriter {
  _MemStore(this.doc);
  PlanDoc doc;
  @override
  Future<void> editPlan(String householdId, PlanTransform transform, {String? by}) async => doc = transform(doc);
}

List _items(PlanDoc d, int g, int c) => (((d['groups'] as List)[g] as Map)['categories'] as List)[c]['items'] as List;

void main() {
  test('항목 수정: 네 칸만 바뀌고 나머지·원본은 그대로', () {
    final src = _doc();
    final out = updatePlanItem(src, 'a',
        const PlanItemFields(monthlyAmount: 1500, payment: '라마바카드', accountId: 'acc1', payDayText: '매월 5일'));
    final plan = Plan.fromJson(out, const {'acc1': '생활비 통장'});
    final a = plan.items.firstWhere((i) => i.id == 'a');
    expect([a.monthlyAmount, a.payment, a.accountName, a.payDayText], [1500, '라마바카드', '생활비 통장', '매월 5일']);
    expect(a.previousPlan, 900);
    expect(plan.items.firstWhere((i) => i.id == 'b').monthlyAmount, 2000);
    expect(Plan.fromJson(src, const {}).items.first.monthlyAmount, 1000, reason: '원본 불변');
  });

  test('빈 통장·결제일은 키를 지운다', () {
    final withAcc = updatePlanItem(_doc(), 'a', const PlanItemFields(monthlyAmount: 1, accountId: 'x', payDayText: '5일'));
    final cleared = updatePlanItem(withAcc, 'a', const PlanItemFields(monthlyAmount: 1));
    final first = _items(cleared, 0, 0).first as Map;
    expect(first.containsKey('accountId'), isFalse);
    expect(first.containsKey('payDayText'), isFalse);
  });

  test('없는 항목 수정·삭제는 오류', () {
    expect(() => updatePlanItem(_doc(), 'zz', const PlanItemFields(monthlyAmount: 1)), throwsA(isA<PlanEditError>()));
    expect(() => deletePlanItem(_doc(), 'zz'), throwsA(isA<PlanEditError>()));
  });

  test('항목 추가: 있는 분류 안에, order 이어서, 새 분류는 만들지 않음', () {
    final out = addPlanItem(_doc(),
        group: '고정', category: '통신', name: ' 새항목 ', fields: const PlanItemFields(monthlyAmount: 300), newId: 'n1');
    final plan = Plan.fromJson(out, const {});
    final n = plan.items.firstWhere((i) => i.id == 'n1');
    expect([n.group, n.category, n.name, n.monthlyAmount], ['고정', '통신', '새항목', 300]);
    expect((_items(out, 0, 0).last as Map)['order'], 2);
    expect(plan.categories.length, 3, reason: '분류 수 그대로');
    expect(
        () => addPlanItem(_doc(),
            group: '고정', category: '없는분류', name: 'x', fields: const PlanItemFields(monthlyAmount: 1), newId: 'n2'),
        throwsA(isA<PlanEditError>()));
    expect(
        () => addPlanItem(_doc(),
            group: '고정', category: '통신', name: ' ', fields: const PlanItemFields(monthlyAmount: 1), newId: 'n3'),
        throwsA(isA<PlanEditError>()));
  });

  test('비어 있던 분류에도 추가되고 문서 구조는 유지', () {
    final out = addPlanItem(_doc(),
        group: '고정', category: '비어있음', name: '새', fields: const PlanItemFields(monthlyAmount: 5), newId: 'n1');
    expect(Plan.fromJson(out, const {}).items.where((i) => i.category == '비어있음').length, 1);
    expect((out['groups'] as List).length, 2);
    expect(out['effectiveFrom'], '2026-01');
  });

  test('삭제는 deleted:true 표시, 합계에서 빠진다', () {
    final out = deletePlanItem(_doc(), 'a');
    expect(Plan.fromJson(out, const {}).total, 2000);
    expect(Plan.fromJson(out, const {}).items.map((i) => i.id), ['b']);
  });

  test('배우자와 순서대로 다른 항목을 고쳐도 서로 덮지 않는다', () async {
    final store = _MemStore(_doc());
    await store.editPlan('h', (d) => updatePlanItem(d, 'a', const PlanItemFields(monthlyAmount: 111)));
    await store.editPlan('h', (d) => updatePlanItem(d, 'b', const PlanItemFields(monthlyAmount: 222)));
    await store.editPlan(
        'h',
        (d) => addPlanItem(d,
            group: '생활비', category: '식비', name: '추가', fields: const PlanItemFields(monthlyAmount: 7), newId: 'z'));
    final plan = Plan.fromJson(store.doc, const {});
    expect(plan.items.map((i) => i.monthlyAmount), [111, 222, 7]);
  });

  test('새 항목 id 는 겹치지 않는다', () {
    expect({for (var i = 0; i < 50; i++) newPlanItemId()}.length, 50);
  });
}
