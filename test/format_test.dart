import 'package:family_finance/core/format/won.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('원화 표기', () {
    expect(won(1234567), '1,234,567원');
    expect(man(1234567), '123만');
    expect(man(45000), '4.5만');
  });
}
