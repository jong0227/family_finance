import 'package:family_finance/core/design/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// DESIGN_SYSTEM 3.6·4.3 — 값을 바꾸면 이 테스트가 잡는다.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final (name, p) in [('라이트', Palette.light), ('다크', Palette.dark)]) {
    test('$name: 글자색은 카드 위 4.5:1 이상', () {
      for (final c in [p.ink, p.textSub, p.textMuted, p.over, p.under, p.info]) {
        expect(_contrast(c, p.surface), greaterThanOrEqualTo(4.5), reason: c.toString());
      }
    });

    test('$name: 의미색 글자는 옅은 면(container) 위에서도 4.5:1 이상', () {
      expect(_contrast(p.over, p.overBg), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.under, p.underBg), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.info, p.infoBg), greaterThanOrEqualTo(4.5));
    });
  }

  test('AppText 스케일은 4.3 표 그대로, 굵기는 400~700 네 개만', () {
    final scale = {
      AppText.micro: 10.0,
      AppText.caption: 11.0,
      AppText.label: 12.0,
      AppText.body: 13.0,
      AppText.bodyStrong: 13.0,
      AppText.title: 14.0,
      AppText.titleLg: 16.0,
      AppText.numMd: 18.0,
      AppText.kpi: 22.0,
      AppText.hero: 26.0,
    };
    const weights = [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700];
    scale.forEach((style, size) {
      expect(style.fontSize, size);
      expect(weights, contains(style.fontWeight));
      expect(style.color, isNull, reason: '색은 테마·팔레트에서 덧입힌다');
    });
  });
}
