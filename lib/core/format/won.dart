import 'package:intl/intl.dart';

final _won = NumberFormat('#,##0', 'ko_KR');

/// 1,234,567원
String won(int amount) => '${_won.format(amount)}원';

/// 123.5만 (DESIGN_SYSTEM 4.4 — 목록·차트용 짧은 표기)
String man(int amount) {
  final v = amount / 10000;
  return '${v.abs() >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}만';
}
