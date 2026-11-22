import 'package:family_finance/data/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('버전 비교', () {
    expect(UpdateService.isNewer('v0.3.0', '0.2.0'), isTrue);
    expect(UpdateService.isNewer('0.2.0', '0.2.0'), isFalse);
    expect(UpdateService.isNewer('0.10.0', '0.9.9'), isTrue);
    expect(UpdateService.normalize('v1.2.3+4'), '1.2.3');
  });
}
