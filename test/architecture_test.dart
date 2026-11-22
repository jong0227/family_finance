import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ARCHITECTURE 3장 의존 규칙: 화면(features)은 data 를 직접 import 하지 않는다.
/// 공유 문서 경로('households', 'inviteCodes')는 data/shared 밖에서 쓰지 않는다.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String norm(File f) => f.path.replaceAll(r'\', '/');

  test('features 는 data 를 직접 import 하지 않는다', () {
    final importsData = RegExp(r"import '[^']*/data/");
    final bad = [
      for (final f in files)
        if (norm(f).contains('lib/features/') && importsData.hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(bad, isEmpty);
  });

  test('화면(features)은 색·글자 크기를 직접 쓰지 않는다 — 디자인 토큰만 (CLAUDE.md 절대 규칙 7)', () {
    final raw = RegExp(r'Color\(0x|Colors\.(?!transparent)|fontSize:|FontWeight\.bold|FontWeight\.normal');
    final bad = [
      for (final f in files)
        if (norm(f).contains('lib/features/'))
          for (final m in raw.allMatches(f.readAsStringSync())) '${f.path}: ${m.group(0)}',
    ];
    expect(bad, isEmpty);
  });

  test('공유 문서 경로는 data/shared 에서만 쓴다', () {
    final sharedPath = RegExp(r"collection\('(households|inviteCodes)'\)");
    final bad = [
      for (final f in files)
        if (!norm(f).contains('lib/data/shared/') && sharedPath.hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(bad, isEmpty);
  });
}
