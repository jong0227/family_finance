// ignore_for_file: avoid_print
// 분류 동일성 검사: 규칙 JSON + 거래 덤프(src + 기존 cls + 월 집계)를 받아 엔진 결과와 비교한다.
// 사용: dart run tool/classify_check.dart <rules.json> <tx_dump.json>
// 개인 데이터는 저장소 밖 파일로만 받고, 출력은 건수뿐이다.
import 'dart:convert';
import 'dart:io';

import 'package:family_finance/domain/classify/classify.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: dart run tool/classify_check.dart <rules.json> <tx_dump.json>');
    exit(64);
  }
  final rules = RuleCodec.decode(jsonDecode(File(args[0]).readAsStringSync()) as Map<String, Object?>);
  final dump = jsonDecode(File(args[1]).readAsStringSync()) as Map<String, Object?>;
  final txs = (dump['transactions'] as List).cast<Map<String, Object?>>();

  var mismatch = 0, kindM = 0, catM = 0, livM = 0, oneM = 0;
  final rows = <({String month, int amount, Classification cls})>[];
  for (final t in txs) {
    final src = (t['src'] as Map).cast<String, Object?>();
    final cls = (t['cls'] as Map).cast<String, Object?>();
    final r = classifyTx(ClassifyInput.fromSrc(src, tags: ((t['tags'] as List?) ?? const []).cast<String>()), rules);
    rows.add((month: t['month'] as String, amount: (src['amount'] as num).toInt(), cls: r));
    final k = r.kind != cls['kind'];
    final c = r.categoryId != cls['categoryId'];
    final l = r.living != cls['living'];
    final o = r.oneOff != (cls['oneOff'] == true);
    if (k) kindM++;
    if (c) catM++;
    if (l) livM++;
    if (o) oneM++;
    if (k || c || l || o) mismatch++;
  }
  print('transactions ${txs.length}');
  print('mismatch $mismatch (kind $kindM, category $catM, living $livM, oneOff $oneM)');

  final agg = aggregateMonths(rows, consumptionKind: rules.consumptionKind);
  final months = (dump['months'] as Map).cast<String, Object?>();
  var monthBad = 0, fieldBad = 0;
  for (final e in months.entries) {
    final exp = (e.value as Map).cast<String, Object?>();
    final got = agg[e.key];
    if (got == null) {
      monthBad++;
      continue;
    }
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    final bad = <bool>[
      got.consumption != n(exp['consumption']),
      got.regular != n(exp['regular']),
      got.oneOff != n(exp['oneOff']),
      got.livingTotal != n((exp['living'] as Map).values.fold<int>(0, (a, b) => a + n(b))),
      got.txCount != n(exp['txCount']),
      !_mapEq(got.living, exp['living']),
      !_mapEq(got.byCategoryRegular, exp['byCategoryRegular']),
      !_mapEq(got.byCategory, exp['byCategory']),
    ].where((b) => b).length;
    fieldBad += bad;
    if (bad > 0) monthBad++;
  }
  print('months ${months.length}, months with mismatch $monthBad, mismatched fields $fieldBad');
  final total = rows.fold<int>(0, (a, r) => a + r.amount);
  final net = agg.values.fold<int>(0, (a, m) => a + m.net);
  print('total preserved: ${total == net}');
  exit(mismatch == 0 && monthBad == 0 && total == net ? 0 : 1);
}

bool _mapEq(Map<String, int> got, Object? exp) {
  final e = (exp as Map).cast<String, Object?>();
  final keys = {...got.keys, ...e.keys};
  for (final k in keys) {
    if ((got[k] ?? 0) != ((e[k] as num?)?.toInt() ?? 0)) return false;
  }
  return true;
}
