import 'package:family_finance/domain/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('월 집계를 읽고 생활비 합을 낸다', () {
    final m = MonthAgg.fromJson({
      'month': '2026-10',
      'consumption': 100,
      'regular': 90,
      'oneOff': 10,
      'byCategoryRegular': {'외식': 40},
      'living': {'배달': 20, '잡화': 30},
      'partial': false,
    });
    expect(m.livingTotal, 50);
    expect(m.byCategoryRegular['외식'], 40);
  });

  test('계획에서 생활비 묶음별 금액을 모은다 (간식·잡화는 둘을 합침)', () {
    item(String name, int amount, String? living) => {
          'id': name, 'name': name, 'monthlyAmount': amount, 'living': living, 'payment': '',
        };
    final plan = Plan.fromJson({
      'groups': [
        {
          'name': '생활비',
          'categories': [
            {'name': '아이1비', 'items': [item('아이간식', 75, '간식'), item('아이잡화', 320, '잡화')]},
            {'name': '식비', 'items': [item('어른간식', 75, '간식'), item('관리비', 300, null)]},
          ],
        },
      ],
    }, const {});
    expect(plan.livingPlan['간식'], 150);
    expect(plan.livingPlan['잡화'], 320);
    expect(plan.total, 770);
  });
}
