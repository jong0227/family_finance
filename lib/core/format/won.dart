import 'package:intl/intl.dart';

final _won = NumberFormat('#,##0', 'ko_KR');

/// 음수 기호는 하이픈이 아니라 마이너스(U+2212) — 숫자 폭이 `+`와 같다(DESIGN_SYSTEM 4.4).
const minus = '−';

String _sign(num v) => v < 0 ? minus : '';

/// 1,234,567원 — 거래 한 건·구독 한 건처럼 정확해야 하는 곳.
String won(int amount) => '${_sign(amount)}${_won.format(amount.abs())}원';

/// 거래 금액: 지출(음수)은 부호 없이, 환불·수입(양수)은 `+` (4.4).
String txWon(int amount) => amount > 0 ? '+${won(amount)}' : won(-amount);

/// 목록·차트용 짧은 표기 (4.4): 8.4만 · 123만 · 1.2억.
String man(int amount) {
  final a = amount.abs();
  if (a >= 100000000) return '${_sign(amount)}${(a / 100000000).toStringAsFixed(1)}억';
  final v = a / 10000;
  // 99.95만 이상은 소수 1자리로 반올림하면 100.0만이 되므로 정수 구간으로 본다.
  return '${_sign(amount)}${v >= 99.95 ? v.round() : v.toStringAsFixed(1)}만';
}
