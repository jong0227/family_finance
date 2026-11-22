/// 할부·정기 대형 지출 타임라인(S2). 계획 항목에서만 만든다 — 없는 정보는 지어내지 않는다.
/// - 할부: 항목 이름·메모에 "3/10회" 같은 회차 표기가 있을 때만 남은 회차·끝나는 달을 계산한다.
///   "할부"라는 말만 있고 회차를 못 읽으면 "회차 미확인"으로 표시한다.
/// - 큰 정기: 월 계획 금액이 [largeMin] 이상인 생활비 묶음 밖 항목.
/// 거래 메모·카드 알림에서 할부 개월 읽기, 연·분기 단위 구독 갱신은 아직 안 한다(추후).
library;

import 'finance_models.dart';

enum TimelineKind { installment, installmentUnknown, large }

class TimelineEntry {
  const TimelineEntry({required this.name, required this.amount, required this.kind, this.remaining, this.endMonth});
  final String name;
  final int amount;
  final TimelineKind kind;

  /// 이번 달 이후 남은 회차(할부, 회차 표기가 있을 때).
  final int? remaining;

  /// 마지막 결제 달 'YYYY-MM'(할부, 회차 표기가 있을 때).
  final String? endMonth;
}

class TimelineMonth {
  const TimelineMonth(this.month, this.entries);
  final String month;
  final List<TimelineEntry> entries;
  int get total => entries.fold(0, (a, e) => a + e.amount);
}

/// "3/10회", "3 / 10 회차" → (현재 회차, 전체 회차). 못 읽으면 null.
({int current, int total})? parseInstallment(String? text) {
  final m = RegExp(r'(\d{1,3})\s*/\s*(\d{1,3})\s*회').firstMatch(text ?? '');
  if (m == null) return null;
  final c = int.parse(m.group(1)!), t = int.parse(m.group(2)!);
  if (t < 1 || c < 1 || c > t) return null;
  return (current: c, total: t);
}

String addMonths(String month, int n) {
  final y = int.parse(month.substring(0, 4)), m = int.parse(month.substring(5, 7));
  final idx = y * 12 + (m - 1) + n;
  return '${idx ~/ 12}-${(idx % 12 + 1).toString().padLeft(2, '0')}';
}

/// [from]('YYYY-MM') 부터 [months] 개월. 회차 표기의 현재 회차는 [from] 달 기준으로 본다.
List<TimelineMonth> buildTimeline({
  required Plan plan,
  required String from,
  int months = 6,
  int largeMin = 300000,
}) {
  final result = <TimelineMonth>[];
  for (var k = 0; k < months; k++) {
    final month = addMonths(from, k);
    final entries = <TimelineEntry>[];
    for (final i in plan.items) {
      if (i.monthlyAmount <= 0) continue;
      final text = '${i.name} ${i.note ?? ''}';
      final inst = parseInstallment(text);
      if (inst != null) {
        final remaining = inst.total - inst.current;
        if (k <= remaining) {
          entries.add(TimelineEntry(
            name: i.name,
            amount: i.monthlyAmount,
            kind: TimelineKind.installment,
            remaining: remaining,
            endMonth: addMonths(from, remaining),
          ));
        }
      } else if (text.contains('할부')) {
        entries.add(TimelineEntry(name: i.name, amount: i.monthlyAmount, kind: TimelineKind.installmentUnknown));
      } else if (i.living == null && i.monthlyAmount >= largeMin) {
        entries.add(TimelineEntry(name: i.name, amount: i.monthlyAmount, kind: TimelineKind.large));
      }
    }
    entries.sort((a, b) => b.amount.compareTo(a.amount));
    result.add(TimelineMonth(month, entries));
  }
  return result;
}
