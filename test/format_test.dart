import 'package:family_finance/core/format/won.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('원화 표기', () {
    expect(won(1234567), '1,234,567원');
    expect(won(0), '0원');
    expect(man(1234567), '123만');
    expect(man(45000), '4.5만');
  });

  test('음수는 하이픈이 아니라 마이너스(U+2212)', () {
    expect(won(-12800), '−12,800원');
    expect(man(-32000), '−3.2만');
  });

  test('만 단위 경계와 억', () {
    expect(man(999400), '99.9만');
    expect(man(999500), '100만'); // 100.0만으로 나오지 않게
    expect(man(120000000), '1.2억');
  });

  test('거래 금액: 지출은 부호 없음, 환불·수입은 +', () {
    expect(txWon(-12800), '12,800원');
    expect(txWon(15000), '+15,000원');
  });
}
