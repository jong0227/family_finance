/// 구독 편집 — ninedogs_core 모델만 쓰는 순수 함수. 코어에 있는 필드만 바꾼다.
library;

import 'dart:math';

import 'package:ninedogs_core/ninedogs_core.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 주인 칸 키가 계약에 맞는지(null = 공동·미지정, 아니면 a/b).
bool isValidOwner(String? owner) => owner == null || People.slots.contains(owner);

/// 새 구독 id (UUID v4 모양 — Ninedogs 가 만드는 id 와 같은 꼴).
String newSubscriptionId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int from, int to) => b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
}

/// 다음 결제일 [next] 가 되도록 맞춘 `billingAnchor`(가장 최근 결제일 = 다음 결제일 한 주기 전).
/// 시작일보다 앞서면 [next] 자체를 기준으로 둔다.
DateTime anchorForNextBilling(Subscription s, DateTime next) {
  final cycle = s.cycle;
  final n = _day(next);
  final prev = cycle.months > 0 ? addMonths(n, -cycle.months) : n.subtract(Duration(days: cycle.days));
  return prev.isBefore(_day(s.startedAt)) ? n : prev;
}

/// 기존 구독을 고친다. 바꾸지 않을 값은 null(주인·메모·결제 수단은 [clearOwner] 등으로 비움).
///
/// - 가격: [priceCorrection] true 면 마지막 가격 칸을 정정, false 면 [priceFrom](기본 오늘)부터 새 가격.
/// - 주기: 바뀌면 옛 칸에 옛 주기를 고정하고 [priceFrom] 부터 새 주기 칸을 더한다(정정이면 그냥 교체).
/// - 다음 결제일: `billingAnchor` 로 환산해 저장.
Subscription editSubscription(
  Subscription s, {
  Money? price,
  BillingCycle? cycle,
  bool priceCorrection = false,
  DateTime? priceFrom,
  DateTime? nextBilling,
  String? owner,
  bool clearOwner = false,
  String? memo,
  bool clearMemo = false,
  String? paymentMethod,
  bool clearPayment = false,
  DateTime? today,
}) {
  final newOwner = clearOwner ? null : owner;
  if ((owner != null || clearOwner) && !isValidOwner(newOwner)) {
    throw ArgumentError.value(owner, 'owner', 'a/b/null 만 가능');
  }
  if (price != null && price.currency != s.currency) {
    throw ArgumentError('통화가 다른 가격은 이력에 섞을 수 없어요');
  }
  final from = _day(priceFrom ?? today ?? DateTime.now());
  final nextCycle = cycle ?? s.cycle;
  final priceChanged = price != null && price != s.currentPrice;
  final cycleChanged = nextCycle != s.cycle;

  var history = s.priceHistory;
  if (priceChanged || cycleChanged) {
    final amount = price ?? s.currentPrice;
    if (priceCorrection) {
      final last = history.last;
      history = [
        ...history.take(history.length - 1),
        PricePoint(effectiveFrom: last.effectiveFrom, amount: amount, cycle: last.cycle == null ? null : nextCycle),
      ];
    } else {
      history = [
        for (final p in history) PricePoint(effectiveFrom: p.effectiveFrom, amount: p.amount, cycle: p.cycle ?? s.cycle),
        PricePoint(effectiveFrom: from, amount: amount, cycle: nextCycle),
      ];
    }
  }

  var out = s.copyWith(
    cycle: nextCycle,
    priceHistory: history,
    owner: (owner != null || clearOwner) ? () => newOwner : null,
    memo: (memo != null || clearMemo) ? () => clearMemo || memo!.trim().isEmpty ? null : memo.trim() : null,
    paymentMethod: (paymentMethod != null || clearPayment)
        ? () => clearPayment || paymentMethod!.trim().isEmpty ? null : paymentMethod.trim()
        : null,
  );
  if (nextBilling != null) {
    final anchor = anchorForNextBilling(out, nextBilling);
    out = out.copyWith(billingAnchor: () => anchor);
  }
  return out;
}

/// 새 구독. 원화 정수 금액.
Subscription newSubscription({
  required String id,
  required String name,
  required int wonAmount,
  required BillingCycle cycle,
  required DateTime startedAt,
  DateTime? nextBilling,
  String? owner,
  String? memo,
  String? paymentMethod,
}) {
  final n = name.trim();
  if (n.isEmpty) throw ArgumentError('이름이 비었어요');
  if (wonAmount < 0) throw ArgumentError('금액이 음수예요');
  if (!isValidOwner(owner)) throw ArgumentError.value(owner, 'owner');
  final start = _day(startedAt);
  var s = Subscription.create(
    id: id,
    name: n,
    cycle: cycle,
    startedAt: start,
    priceHistory: [PricePoint(effectiveFrom: start, amount: Money(wonAmount), cycle: cycle)],
    owner: owner,
    memo: (memo ?? '').trim().isEmpty ? null : memo!.trim(),
    paymentMethod: (paymentMethod ?? '').trim().isEmpty ? null : paymentMethod!.trim(),
  );
  if (nextBilling != null) {
    final anchor = anchorForNextBilling(s, nextBilling);
    s = s.copyWith(billingAnchor: () => anchor);
  }
  return s;
}
