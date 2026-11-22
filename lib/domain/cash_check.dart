/// 결제일 현금 점검(S1). 통장별로 계획에서 빠질 돈 vs 직접 입력한 잔액. Flutter·Firebase 를 모른다.
/// 실시간 잔액이 없으므로 잔액은 사용자가 입력한 값만 쓴다(없으면 "잔액 미입력").
library;

import 'finance_models.dart';
import 'pay_day.dart';

/// 통장 하나에서 나가는 돈 한 줄.
class Outflow {
  const Outflow({required this.name, required this.amount, required this.isCard, required this.date, required this.payDayText});
  final String name;
  final int amount;

  /// true: 카드 대금(계획의 카드 항목을 합친 추정), false: 자동이체·고정 출금.
  final bool isCard;

  /// 보정된 날짜. null 이면 결제일을 읽지 못함("날짜 미정").
  final DateTime? date;
  final String? payDayText;
}

class AccountCash {
  const AccountCash({
    required this.accountId,
    required this.name,
    required this.balance,
    required this.excluded,
    required this.outflows,
  });
  final String? accountId;
  final String name;

  /// 입력한 잔액. null = 미입력.
  final int? balance;

  /// "쓸 수 없는 돈" 표시 — 여유로 치지 않는다.
  final bool excluded;

  /// 날짜순(날짜 미정은 맨 뒤).
  final List<Outflow> outflows;

  int get datedTotal => outflows.where((o) => o.date != null).fold(0, (a, o) => a + o.amount);
  int get undatedTotal => outflows.where((o) => o.date == null).fold(0, (a, o) => a + o.amount);
  int get total => datedTotal + undatedTotal;
  int get cardTotal => outflows.where((o) => o.isCard).fold(0, (a, o) => a + o.amount);

  /// 날짜가 있는 출금 기준 부족액(0 이상). 잔액 미입력이면 null.
  int? get shortfall => balance == null ? null : _pos(datedTotal - balance!);

  /// 날짜 미정까지 모두 나간다고 보면 부족액.
  int? get shortfallWithUndated => balance == null ? null : _pos(total - balance!);

  /// 남는 돈(잔액 − 전체 출금, 0 이상). 제외 표시한 통장은 0.
  int get spare => balance == null || excluded ? 0 : _pos(balance! - total);

  /// 날짜 있는 출금을 순서대로 빼 보며 처음 모자라는 날짜.
  DateTime? get firstShortDate {
    if (balance == null) return null;
    var left = balance!;
    for (final o in outflows) {
      if (o.date == null) continue;
      left -= o.amount;
      if (left < 0) return o.date;
    }
    return null;
  }

  static int _pos(int v) => v > 0 ? v : 0;
}

class CashCheckResult {
  const CashCheckResult({required this.accounts, required this.unassigned});
  final List<AccountCash> accounts;

  /// 출금 통장을 안 정한 계획 항목(점검에서 빠짐) — 화면에 따로 알린다.
  final List<PlanItem> unassigned;

  int get shortfallTotal => accounts.fold(0, (a, c) => a + (c.shortfall ?? 0));
  int get spareTotal => accounts.fold(0, (a, c) => a + c.spare);
  int get missingBalanceCount => accounts.where((c) => c.balance == null).length;
}

bool isCardItem(PlanItem i) => (i.cardId ?? '').isNotEmpty || i.payment.contains('카드');

/// 카드 한 장(`cards/{cardId}`): 카드값은 항목의 결제일이 아니라 카드의 결제일에 출금 통장에서 빠진다.
class CardRef {
  const CardRef({required this.id, required this.nickname, this.payDay, this.withdrawalAccountId});
  final String id, nickname;

  /// 매월 결제일(1~31). null 이면 모름 → "날짜 미정".
  final int? payDay;
  final String? withdrawalAccountId;
}

/// [month] 의 점검. 금액 0 이하 항목은 뺀다. 생활비 묶음 항목도 계획 금액으로 포함한다(카드 줄에 "계획 기준 추정").
/// - cardId 가 있는 항목: 통장 = 카드의 출금 통장(없으면 항목의 통장), 날짜 = 카드 결제일(없으면 날짜 미정). 카드당 한 줄. 항목의 결제일 문구는 무시.
/// - cardId 없이 payment 에 '카드'가 들어간 항목: 항목의 통장 아래 카드 줄, 날짜 미정.
/// - 그 밖: 항목의 통장·결제일 문구대로 한 줄씩.
CashCheckResult computeCashCheck({
  required String month,
  required Plan plan,
  required Map<String, int> balances,
  Set<String> excluded = const {},
  Map<String, String> accountNames = const {},
  Map<String, CardRef> cards = const {},
}) {
  final unassigned = <PlanItem>[];
  // 통장 → 줄 키 → 항목들
  final byAcc = <String, Map<String, List<PlanItem>>>{};
  for (final i in plan.items) {
    if (i.monthlyAmount <= 0) continue;
    final cid = i.cardId ?? '';
    final card = cid.isEmpty ? null : cards[cid];
    final acc = cid.isNotEmpty ? ((card?.withdrawalAccountId ?? '').isNotEmpty ? card!.withdrawalAccountId : i.accountId) : i.accountId;
    if (acc == null || acc.isEmpty) {
      unassigned.add(i);
      continue;
    }
    final key = cid.isNotEmpty
        ? 'card:$cid'
        : isCardItem(i)
            ? 'text:${i.payment}'
            : 'item:${i.id}';
    byAcc.putIfAbsent(acc, () => {}).putIfAbsent(key, () => []).add(i);
  }

  final accounts = <AccountCash>[];
  for (final e in byAcc.entries) {
    final out = <Outflow>[];
    for (final line in e.value.entries) {
      final items = line.value;
      final sum = items.fold<int>(0, (a, i) => a + i.monthlyAmount);
      if (line.key.startsWith('item:')) {
        final i = items.first;
        final pd = parsePayDay(i.payDayText);
        out.add(Outflow(
            name: i.name, amount: sum, isCard: false, date: pd == null ? null : payDateIn(month, pd), payDayText: i.payDayText));
        continue;
      }
      final estimate = items.any((i) => i.living != null) ? ' · 계획 기준 추정' : '';
      String label;
      PayDay? pd;
      String? text;
      if (line.key.startsWith('card:')) {
        final card = cards[line.key.substring(5)];
        label = (card?.nickname ?? '').isNotEmpty ? card!.nickname : (items.first.payment.isEmpty ? '카드' : items.first.payment);
        final d = card?.payDay;
        pd = d != null && d >= 1 && d <= 31 ? PayDay.day(d) : null;
        text = pd == null ? null : '${pd.day}일';
      } else {
        label = items.first.payment.isEmpty ? '카드' : items.first.payment;
      }
      out.add(Outflow(
        name: '$label 대금 (항목 ${items.length}개)$estimate',
        amount: sum,
        isCard: true,
        date: pd == null ? null : payDateIn(month, pd),
        payDayText: text,
      ));
    }
    out.sort((a, b) {
      if (a.date == null && b.date == null) return b.amount.compareTo(a.amount);
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      final c = a.date!.compareTo(b.date!);
      return c != 0 ? c : b.amount.compareTo(a.amount);
    });
    accounts.add(AccountCash(
      accountId: e.key,
      name: accountNames[e.key] ?? e.key,
      balance: balances[e.key],
      excluded: excluded.contains(e.key),
      outflows: out,
    ));
  }
  accounts.sort((a, b) => b.total.compareTo(a.total));
  return CashCheckResult(accounts: accounts, unassigned: unassigned);
}

/// 사용자가 입력한 값(`cashCheck/{월}` 문서): 통장별 잔액과 "쓸 수 없는 돈" 표시.
class CashCheckInput {
  const CashCheckInput({this.balances = const {}, this.excluded = const {}});
  final Map<String, int> balances;
  final Set<String> excluded;
}
