import 'rule.dart';

/// 분류 결과. `ruleIds` 는 값을 채운 규칙(적용 순서).
class Classification {
  const Classification({this.kind, this.categoryId, this.living, this.oneOff = false, this.ruleIds = const []});

  final String? kind, categoryId, living;
  final bool oneOff;
  final List<String> ruleIds;
}

/// 거래 하나를 분류하는 순수 함수.
///
/// 규칙은 [RuleSet.rules] 순서대로 훑는다.
/// - 일반 규칙: 아직 비어 있는 필드만 채운다(먼저 채운 규칙이 이긴다).
/// - `override` 규칙: 일반 규칙이 채운 값도 덮는다. 덮어쓰기 규칙끼리는 먼저 채운 쪽이 이긴다.
/// - `then` 에 kind 가 있는 규칙은 "판정 묶음"이다. kind 를 채울 수 없는 상황(이미 정해짐)이면 그 규칙은 통째로 건너뛴다
///   — kind 와 같이 적은 분류만 따로 새어 들어가지 않게.
/// - 조건 `kind`·`categoryId`·`oneOff` 는 앞선 규칙이 정한 값을 본다. 그러니 이 값에 기대는 규칙은 그 값을 정하는 규칙 뒤에 둔다.
Classification classifyTx(ClassifyInput tx, RuleSet rules) {
  final st = _State();
  final cache = _Cache(tx);
  for (final r in rules.rules) {
    if (!r.enabled) continue;
    if (!_matches(r.match, tx, st, cache)) continue;
    final t = r.then;
    if (t.setKind && !st.kind.canSet(r.override)) continue;
    var applied = false;
    if (t.setKind) applied |= st.kind.set(t.kind, r.override);
    if (t.setCategoryId) applied |= st.categoryId.set(t.categoryId, r.override);
    if (t.setLiving) applied |= st.living.set(t.living, r.override);
    if (t.setOneOff) applied |= st.oneOff.set(t.oneOff, r.override);
    if (applied) st.ids.add(r.id);
  }
  return Classification(
    kind: st.kind.value as String?,
    categoryId: st.categoryId.value as String?,
    living: st.living.value as String?,
    oneOff: (st.oneOff.value as bool?) ?? false,
    ruleIds: st.ids,
  );
}

class _Slot {
  Object? value;
  int by = 0; // 0 비어 있음, 1 일반 규칙, 2 덮어쓰기 규칙
  bool canSet(bool override) => by == 0 || (override && by == 1);
  bool set(Object? v, bool override) {
    if (!canSet(override)) return false;
    value = v;
    by = override ? 2 : 1;
    return true;
  }
}

class _State {
  final kind = _Slot(), categoryId = _Slot(), living = _Slot(), oneOff = _Slot();
  final ids = <String>[];
}

class _Cache {
  _Cache(ClassifyInput tx)
      : merchant = tx.merchant ?? '',
        payment = tx.payment ?? '',
        memo = tx.memo ?? '',
        major = tx.major ?? '',
        minor = tx.minor ?? '';
  final String merchant, payment, memo, major, minor;
}

bool _any(List<String> keys, bool Function(String) f) {
  for (final k in keys) {
    if (f(k)) return true;
  }
  return false;
}

bool _matches(RuleMatch m, ClassifyInput tx, _State st, _Cache c) {
  if (m.type != null && !m.type!.contains(tx.type)) return false;
  if (m.major != null && !m.major!.contains(c.major)) return false;
  if (m.minor != null && !m.minor!.contains(c.minor)) return false;
  if (m.merchantEquals != null && !m.merchantEquals!.contains(c.merchant)) return false;
  if (m.merchantContains != null && !_any(m.merchantContains!, c.merchant.contains)) return false;
  if (m.merchantStartsWith != null && !_any(m.merchantStartsWith!, c.merchant.startsWith)) return false;
  if (m.merchantRegex != null && !m.merchantRegex!.hasMatch(c.merchant)) return false;
  if (m.paymentIn != null && !m.paymentIn!.contains(c.payment)) return false;
  if (m.paymentStartsWith != null && !_any(m.paymentStartsWith!, c.payment.startsWith)) return false;
  if (m.paymentContains != null && !_any(m.paymentContains!, c.payment.contains)) return false;
  if (m.accountId != null && !m.accountId!.contains(tx.accountId ?? '')) return false;
  if (m.cardId != null && !m.cardId!.contains(tx.cardId ?? '')) return false;
  if (m.tag != null && !_any(m.tag!, tx.tags.contains)) return false;
  if (m.memoContains != null && !_any(m.memoContains!, c.memo.contains)) return false;
  final a = tx.amount, abs = a.abs();
  if (m.amountEq != null && a != m.amountEq) return false;
  if (m.amountMin != null && a < m.amountMin!) return false;
  if (m.amountMax != null && a > m.amountMax!) return false;
  if (m.amountAbsEq != null && abs != m.amountAbsEq) return false;
  if (m.amountAbsMin != null && abs < m.amountAbsMin!) return false;
  if (m.amountAbsMax != null && abs > m.amountAbsMax!) return false;
  if (m.dateFrom != null && tx.date.compareTo(m.dateFrom!) < 0) return false;
  if (m.dateTo != null && tx.date.compareTo(m.dateTo!) > 0) return false;
  if (m.dayFrom != null || m.dayTo != null) {
    final day = int.tryParse(tx.date.length >= 10 ? tx.date.substring(8, 10) : '') ?? 0;
    if (m.dayFrom != null && day < m.dayFrom!) return false;
    if (m.dayTo != null && day > m.dayTo!) return false;
  }
  if (m.kind != null && !m.kind!.contains(st.kind.value)) return false;
  if (m.categoryId != null && !m.categoryId!.contains(st.categoryId.value)) return false;
  if (m.oneOff != null && ((st.oneOff.value as bool?) ?? false) != m.oneOff) return false;
  if (m.anyOf != null && !m.anyOf!.any((s) => _matches(s, tx, st, c))) return false;
  if (m.not != null && _matches(m.not!, tx, st, c)) return false;
  return true;
}
