/// 결제일 문구("매월 21일", "말일" …) 해석과 영업일 보정. Flutter·Firebase 를 모른다.
library;

/// 해석한 결제일. [lastDay] 가 true 면 매월 말일.
class PayDay {
  const PayDay.day(int this.day) : lastDay = false;
  const PayDay.last()
      : day = null,
        lastDay = true;
  final int? day;
  final bool lastDay;

  @override
  bool operator ==(Object other) => other is PayDay && other.day == day && other.lastDay == lastDay;
  @override
  int get hashCode => Object.hash(day, lastDay);
}

/// 알 수 없으면 null (화면에서 "날짜 미정"). 주 단위·요일·여러 날짜가 섞인 문구는 추측하지 않는다.
PayDay? parsePayDay(String? text) {
  final t = (text ?? '').trim();
  if (t.isEmpty) return null;
  if (RegExp(r'매주|요일|격주|분기|매년|연납|\d\s*월\s*\d').hasMatch(t)) return null;
  if (t.contains('말일') || t.contains('월말')) return const PayDay.last();
  final nums = RegExp(r'\d+').allMatches(t).map((m) => int.parse(m.group(0)!)).toList();
  if (nums.length != 1) return null;
  final d = nums.first;
  if (d < 1 || d > 31) return null;
  return PayDay.day(d);
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// [month]('YYYY-MM') 안의 실제 날짜. 31일이 없는 달은 말일로 당기고, 토·일이면 다음 월요일로 민다.
/// 공휴일은 모른다(주말만 보정) — 화면에 그렇게 적는다.
DateTime? payDateIn(String month, PayDay pd) {
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(month);
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!);
  if (mo < 1 || mo > 12) return null;
  final last = daysInMonth(y, mo);
  var d = DateTime(y, mo, pd.lastDay ? last : (pd.day! > last ? last : pd.day!));
  while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}
