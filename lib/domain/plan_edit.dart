/// 계획 편집 — 계획 문서(`planVersions/{id}`)의 Map 을 받아 새 Map 을 돌려주는 순수 함수들.
/// 구분·지출 분류는 이름을 바꾸거나 합치지 않는다. 항목만 고치고·더하고·지운다(지움 = `deleted:true`).
library;

import 'dart:math';

/// 계획 문서 Map (`groups` 가 들어 있는 문서 전체).
typedef PlanDoc = Map<String, Object?>;

/// 읽은 계획 문서를 받아 고친 문서를 돌려주는 함수. 저장소가 트랜잭션 안에서 부른다.
typedef PlanTransform = PlanDoc Function(PlanDoc current);

/// 계획 문서를 쓰는 곳 (실제 구현은 data, 테스트는 메모리).
abstract class PlanWriter {
  /// 가장 최근 계획 문서를 읽고 → [transform] → 저장. 읽기·쓰기가 한 트랜잭션이라
  /// 배우자가 동시에 고친 다른 항목을 덮지 않는다(충돌 시 다시 읽어 재시도).
  Future<void> editPlan(String householdId, PlanTransform transform, {String? by});
}

class PlanEditError implements Exception {
  const PlanEditError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 항목 편집 시트가 바꾸는 네 칸.
class PlanItemFields {
  const PlanItemFields({required this.monthlyAmount, this.payment = '', this.accountId, this.payDayText});
  final int monthlyAmount;
  final String payment;
  final String? accountId;
  final String? payDayText;
}

Map<String, Object?> _copy(Map m) => {for (final e in m.entries) e.key as String: _deep(e.value)};
Object? _deep(Object? v) => v is Map ? _copy(v) : v is List ? [for (final e in v) _deep(e)] : v;

void _applyFields(Map<String, Object?> item, PlanItemFields f) {
  item['monthlyAmount'] = f.monthlyAmount;
  item['payment'] = f.payment.trim();
  void opt(String key, String? v) {
    final t = v?.trim();
    if (t == null || t.isEmpty) {
      item.remove(key);
    } else {
      item[key] = t;
    }
  }

  opt('accountId', f.accountId);
  opt('payDayText', f.payDayText);
}

/// 항목 하나의 월 금액·결제 수단·출금 통장·결제일을 바꾼다. 그 밖의 필드는 그대로.
PlanDoc updatePlanItem(PlanDoc doc, String itemId, PlanItemFields fields) {
  final out = _copy(doc);
  var found = false;
  for (final item in _items(out)) {
    if (item['id'] == itemId && item['deleted'] != true) {
      _applyFields(item, fields);
      found = true;
    }
  }
  if (!found) throw const PlanEditError('항목을 찾지 못했어요. 다른 기기에서 지웠을 수 있어요');
  return out;
}

/// 기존 (구분, 지출 분류) 안에 항목을 더한다. 없는 분류는 만들지 않는다.
PlanDoc addPlanItem(
  PlanDoc doc, {
  required String group,
  required String category,
  required String name,
  required PlanItemFields fields,
  required String newId,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) throw const PlanEditError('항목 이름이 비었어요');
  final out = _copy(doc);
  for (final g in (out['groups'] as List? ?? const [])) {
    final gm = g as Map<String, Object?>;
    if (gm['name'] != group) continue;
    for (final c in (gm['categories'] as List? ?? const [])) {
      final cm = c as Map<String, Object?>;
      if (cm['name'] != category) continue;
      final items = (cm['items'] as List?) ?? (cm['items'] = <Object?>[]);
      final ids = {for (final i in _items(out)) i['id']};
      if (ids.contains(newId)) throw const PlanEditError('항목 id 가 겹쳐요');
      final item = <String, Object?>{
        'id': newId,
        'name': trimmed,
        'previousPlan': 0,
        'deleted': false,
      };
      // 이 분류의 다른 항목이 order 를 쓰면 맨 뒤에 붙인다 (문서 모양 유지).
      final orders = [for (final i in items) if ((i as Map)['order'] is num) ((i)['order'] as num).toInt()];
      if (orders.isNotEmpty) item['order'] = orders.reduce(max) + 1;
      _applyFields(item, fields);
      items.add(item);
      return out;
    }
  }
  throw const PlanEditError('그 구분·지출 분류를 찾지 못했어요');
}

/// 항목을 지운 것으로 표시한다(`deleted:true`). 문서에서 없애지 않아 과거 달 비교가 깨지지 않는다.
PlanDoc deletePlanItem(PlanDoc doc, String itemId) {
  final out = _copy(doc);
  var found = false;
  for (final item in _items(out)) {
    if (item['id'] == itemId && item['deleted'] != true) {
      item['deleted'] = true;
      found = true;
    }
  }
  if (!found) throw const PlanEditError('항목을 찾지 못했어요. 다른 기기에서 지웠을 수 있어요');
  return out;
}

Iterable<Map<String, Object?>> _items(Map<String, Object?> doc) sync* {
  for (final g in (doc['groups'] as List? ?? const [])) {
    for (final c in ((g as Map)['categories'] as List? ?? const [])) {
      for (final i in ((c as Map)['items'] as List? ?? const [])) {
        yield i as Map<String, Object?>;
      }
    }
  }
}

/// 새 항목 id (충돌 확률 무시할 수준의 무작위 16진수).
String newPlanItemId([Random? random]) {
  final r = random ?? Random.secure();
  final hex = [for (var i = 0; i < 4; i++) r.nextInt(1 << 32).toRadixString(16).padLeft(8, '0')].join();
  return 'p$hex';
}
