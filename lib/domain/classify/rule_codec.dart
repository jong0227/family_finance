import 'rule.dart';

/// 규칙 JSON <-> 모델. 모르는 키·잘못된 타입은 [FormatException] — 오타가 조건을 조용히 빼 버려
/// 규칙이 엉뚱한 거래에 걸리는 것을 막는다.
///
/// ```
/// { "v":1, "consumptionKind":"spend",
///   "rules":[ { "id":"r1", "override":false, "priority":0, "enabled":true,
///               "when":{...}, "then":{ "kind":"spend", "categoryId":"food", "living":null, "oneOff":false } } ] }
/// ```
class RuleCodec {
  const RuleCodec._();

  static const _matchKeys = {
    'type', 'major', 'minor', 'merchantEquals', 'merchantContains', 'merchantStartsWith', 'merchantRegex',
    'paymentIn', 'paymentStartsWith', 'paymentContains', 'accountId', 'cardId', 'tag', 'memoContains',
    'amountEq', 'amountMin', 'amountMax', 'amountAbsEq', 'amountAbsMin', 'amountAbsMax',
    'dateFrom', 'dateTo', 'dayOfMonth', 'kind', 'categoryId', 'oneOff', 'anyOf', 'not',
  };
  static const _thenKeys = {'kind', 'categoryId', 'living', 'oneOff'};
  static const _ruleKeys = {'id', 'when', 'then', 'override', 'priority', 'enabled', 'note'};
  static const _setKeys = {'v', 'consumptionKind', 'rules'};
  static final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// 규칙 한 벌을 읽는다. `priority` 가 큰 규칙이 앞서고, 같으면 목록 순서(안정 정렬).
  static RuleSet decode(Map<String, Object?> json) {
    _checkKeys(json, _setKeys, 'ruleset');
    final v = json['v'];
    if (v != 1) throw FormatException('지원하지 않는 규칙 버전: $v');
    final list = json['rules'];
    if (list is! List) throw const FormatException('rules 는 목록이어야 합니다');
    final rules = <ClassifyRule>[];
    final ids = <String>{};
    for (var i = 0; i < list.length; i++) {
      final r = _rule(list[i], i);
      if (!ids.add(r.id)) throw FormatException('규칙 id 중복: ${r.id}');
      rules.add(r);
    }
    final indexed = [for (var i = 0; i < rules.length; i++) (i, rules[i])]
      ..sort((a, b) {
        final c = b.$2.priority.compareTo(a.$2.priority);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    final ck = json['consumptionKind'];
    if (ck != null && ck is! String) throw const FormatException('consumptionKind 는 문자열');
    return RuleSet(
      version: 1,
      consumptionKind: (ck as String?) ?? 'spend',
      rules: [for (final e in indexed) e.$2],
    );
  }

  static Map<String, Object?> encode(RuleSet set) => {
        'v': set.version,
        'consumptionKind': set.consumptionKind,
        'rules': [for (final r in set.rules) _encodeRule(r)],
      };

  // ---- decode ----

  static void _checkKeys(Map<dynamic, dynamic> m, Set<String> allowed, String where) {
    for (final k in m.keys) {
      if (!allowed.contains(k)) throw FormatException('$where: 모르는 키 "$k"');
    }
  }

  static Map<String, Object?> _map(Object? o, String where) {
    if (o is! Map) throw FormatException('$where 는 객체여야 합니다');
    return o.cast<String, Object?>();
  }

  static ClassifyRule _rule(Object? o, int index) {
    final m = _map(o, 'rules[$index]');
    _checkKeys(m, _ruleKeys, 'rules[$index]');
    final id = m['id'];
    if (id is! String || id.isEmpty) throw FormatException('rules[$index].id 가 없습니다');
    final pr = m['priority'];
    if (pr != null && pr is! int) throw FormatException('$id.priority 는 정수');
    final ov = m['override'];
    final en = m['enabled'];
    if ((ov != null && ov is! bool) || (en != null && en is! bool)) {
      throw FormatException('$id: override·enabled 는 true/false');
    }
    final note = m['note'];
    if (note != null && note is! String) throw FormatException('$id.note 는 문자열');
    if (m['then'] == null) throw FormatException('$id: then 이 없습니다');
    return ClassifyRule(
      id: id,
      match: _match(m['when'] ?? const <String, Object?>{}, id),
      then: _then(m['then'], id),
      override: (ov as bool?) ?? false,
      priority: (pr as int?) ?? 0,
      enabled: (en as bool?) ?? true,
      note: note as String?,
    );
  }

  static List<String>? _strs(Map<String, Object?> m, String k, String id) {
    if (!m.containsKey(k)) return null;
    final v = m[k];
    if (v is String) return [v];
    if (v is List && v.every((e) => e is String)) {
      if (v.isEmpty) throw FormatException('$id.when.$k 가 비어 있습니다');
      return v.cast<String>();
    }
    throw FormatException('$id.when.$k 는 문자열 또는 문자열 목록');
  }

  static int? _int(Map<String, Object?> m, String k, String id) {
    if (!m.containsKey(k)) return null;
    final v = m[k];
    if (v is int) return v;
    throw FormatException('$id.when.$k 는 정수');
  }

  static String? _date(Map<String, Object?> m, String k, String id) {
    if (!m.containsKey(k)) return null;
    final v = m[k];
    if (v is String && _dateRe.hasMatch(v)) return v;
    throw FormatException('$id.when.$k 는 YYYY-MM-DD');
  }

  static RuleMatch _match(Object? o, String id) {
    final m = _map(o, '$id.when');
    _checkKeys(m, _matchKeys, '$id.when');
    RegExp? re;
    String? reSrc;
    if (m.containsKey('merchantRegex')) {
      final s = m['merchantRegex'];
      if (s is! String) throw FormatException('$id.when.merchantRegex 는 문자열');
      try {
        re = RegExp(s);
      } on FormatException {
        throw FormatException('$id.when.merchantRegex 가 정규식이 아닙니다');
      }
      reSrc = s;
    }
    int? dayFrom, dayTo;
    if (m.containsKey('dayOfMonth')) {
      final d = _map(m['dayOfMonth'], '$id.when.dayOfMonth');
      _checkKeys(d, const {'from', 'to'}, '$id.when.dayOfMonth');
      final f = d['from'], t = d['to'];
      if ((f != null && f is! int) || (t != null && t is! int) || (f == null && t == null)) {
        throw FormatException('$id.when.dayOfMonth 는 {from?, to?} 정수');
      }
      dayFrom = f as int?;
      dayTo = t as int?;
    }
    List<RuleMatch>? anyOf;
    if (m.containsKey('anyOf')) {
      final a = m['anyOf'];
      if (a is! List || a.isEmpty) throw FormatException('$id.when.anyOf 는 비어 있지 않은 목록');
      anyOf = [for (final e in a) _match(e, id)];
    }
    final ob = m['oneOff'];
    if (ob != null && ob is! bool) throw FormatException('$id.when.oneOff 는 true/false');
    return RuleMatch(
      type: _strs(m, 'type', id),
      major: _strs(m, 'major', id),
      minor: _strs(m, 'minor', id),
      merchantEquals: _strs(m, 'merchantEquals', id),
      merchantContains: _strs(m, 'merchantContains', id),
      merchantStartsWith: _strs(m, 'merchantStartsWith', id),
      merchantRegex: re,
      merchantRegexSource: reSrc,
      paymentIn: _strs(m, 'paymentIn', id),
      paymentStartsWith: _strs(m, 'paymentStartsWith', id),
      paymentContains: _strs(m, 'paymentContains', id),
      accountId: _strs(m, 'accountId', id),
      cardId: _strs(m, 'cardId', id),
      tag: _strs(m, 'tag', id),
      memoContains: _strs(m, 'memoContains', id),
      amountEq: _int(m, 'amountEq', id),
      amountMin: _int(m, 'amountMin', id),
      amountMax: _int(m, 'amountMax', id),
      amountAbsEq: _int(m, 'amountAbsEq', id),
      amountAbsMin: _int(m, 'amountAbsMin', id),
      amountAbsMax: _int(m, 'amountAbsMax', id),
      dateFrom: _date(m, 'dateFrom', id),
      dateTo: _date(m, 'dateTo', id),
      dayFrom: dayFrom,
      dayTo: dayTo,
      kind: _strs(m, 'kind', id),
      categoryId: _strs(m, 'categoryId', id),
      oneOff: ob as bool?,
      anyOf: anyOf,
      not: m.containsKey('not') ? _match(m['not'], id) : null,
    );
  }

  static RuleThen _then(Object? o, String id) {
    final m = _map(o, '$id.then');
    _checkKeys(m, _thenKeys, '$id.then');
    if (m.isEmpty) throw FormatException('$id.then 이 비어 있습니다');
    String? str(String k) {
      final v = m[k];
      if (v != null && v is! String) throw FormatException('$id.then.$k 는 문자열 또는 null');
      return v as String?;
    }

    final oo = m['oneOff'];
    if (oo != null && oo is! bool) throw FormatException('$id.then.oneOff 는 true/false 또는 null');
    return RuleThen(
      setKind: m.containsKey('kind'),
      kind: str('kind'),
      setCategoryId: m.containsKey('categoryId'),
      categoryId: str('categoryId'),
      setLiving: m.containsKey('living'),
      living: str('living'),
      setOneOff: m.containsKey('oneOff'),
      oneOff: oo as bool?,
    );
  }

  // ---- encode ----

  static Map<String, Object?> _encodeRule(ClassifyRule r) => {
        'id': r.id,
        if (r.note != null) 'note': r.note,
        if (!r.enabled) 'enabled': false,
        if (r.priority != 0) 'priority': r.priority,
        if (r.override) 'override': true,
        'when': _encodeMatch(r.match),
        'then': {
          if (r.then.setKind) 'kind': r.then.kind,
          if (r.then.setCategoryId) 'categoryId': r.then.categoryId,
          if (r.then.setLiving) 'living': r.then.living,
          if (r.then.setOneOff) 'oneOff': r.then.oneOff,
        },
      };

  static Map<String, Object?> _encodeMatch(RuleMatch m) => {
        if (m.type != null) 'type': m.type,
        if (m.major != null) 'major': m.major,
        if (m.minor != null) 'minor': m.minor,
        if (m.merchantEquals != null) 'merchantEquals': m.merchantEquals,
        if (m.merchantContains != null) 'merchantContains': m.merchantContains,
        if (m.merchantStartsWith != null) 'merchantStartsWith': m.merchantStartsWith,
        if (m.merchantRegexSource != null) 'merchantRegex': m.merchantRegexSource,
        if (m.paymentIn != null) 'paymentIn': m.paymentIn,
        if (m.paymentStartsWith != null) 'paymentStartsWith': m.paymentStartsWith,
        if (m.paymentContains != null) 'paymentContains': m.paymentContains,
        if (m.accountId != null) 'accountId': m.accountId,
        if (m.cardId != null) 'cardId': m.cardId,
        if (m.tag != null) 'tag': m.tag,
        if (m.memoContains != null) 'memoContains': m.memoContains,
        if (m.amountEq != null) 'amountEq': m.amountEq,
        if (m.amountMin != null) 'amountMin': m.amountMin,
        if (m.amountMax != null) 'amountMax': m.amountMax,
        if (m.amountAbsEq != null) 'amountAbsEq': m.amountAbsEq,
        if (m.amountAbsMin != null) 'amountAbsMin': m.amountAbsMin,
        if (m.amountAbsMax != null) 'amountAbsMax': m.amountAbsMax,
        if (m.dateFrom != null) 'dateFrom': m.dateFrom,
        if (m.dateTo != null) 'dateTo': m.dateTo,
        if (m.dayFrom != null || m.dayTo != null)
          'dayOfMonth': {if (m.dayFrom != null) 'from': m.dayFrom, if (m.dayTo != null) 'to': m.dayTo},
        if (m.kind != null) 'kind': m.kind,
        if (m.categoryId != null) 'categoryId': m.categoryId,
        if (m.oneOff != null) 'oneOff': m.oneOff,
        if (m.anyOf != null) 'anyOf': [for (final a in m.anyOf!) _encodeMatch(a)],
        if (m.not != null) 'not': _encodeMatch(m.not!),
      };
}
