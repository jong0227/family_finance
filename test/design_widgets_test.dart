import 'package:family_finance/core/design/components.dart';
import 'package:family_finance/core/design/theme.dart';
import 'package:family_finance/core/design/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 디자인 견본(가짜 값)을 좁은 폭(플립 겉화면 정도)·라이트/다크로 그려서 넘침·테마 오류가 없는지 본다.
void main() {
  for (final b in Brightness.values) {
    testWidgets('견본 화면 — $b, 폭 360', (tester) async {
      tester.view.physicalSize = const Size(360, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(b),
        home: Scaffold(
          body: ListView(children: [
            MonthSwitcher(month: '2026-11', months: const ['2026-10', '2026-11'], onChanged: (_) {}, note: '18일까지'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                KpiTile(label: '지출 (일회성 제외)', value: '184만', sub: '1,842,000원'),
                SizedBox(width: 8),
                KpiTile(label: '생활비 / 계획', value: '123.4만', sub: '12.3만 초과'),
                SizedBox(width: 8),
                KpiTile(label: '일회성 (100만+)', value: '0.0만', sub: '없음'),
              ]),
            ),
            const SectionCard(
              title: '생활비 — 계획 대비',
              trailing: '이번 달은 진행 중',
              child: Column(children: [
                BudgetRow(name: '어른 식비', actual: 452000, plan: 300000),
                BudgetRow(name: '아이 간식', actual: 81000, plan: 150000),
                BudgetRow(name: '잡화', actual: 100000, plan: 100000),
              ]),
            ),
            SectionCard(
              title: '무엇에 썼나',
              trailing: '일회성 제외 · 눌러서 그 분류만',
              list: true,
              child: Column(children: [
                AmountRow(title: '식비', sub: '24%', amount: '45.2만', onTap: () {}, selected: true),
                AmountRow(title: '가나다마트', sub: '11/18 · 가나다카드', amount: '+15,000원', divider: false, onTap: () {}),
              ]),
            ),
            ChipBar(children: [
              ChoiceChip(label: const Text('전체'), selected: true, onSelected: (_) {}),
              ChoiceChip(label: const Text('생활비'), selected: false, onSelected: (_) {}),
            ]),
            PageHeader('정기',
                trailing: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [ButtonSegment(value: 0, label: Text('고정지출')), ButtonSegment(value: 1, label: Text('구독'))],
                  selected: const {0},
                  onSelectionChanged: (_) {},
                )),
            const OwnerBadge(name: '가', owner: 'a'),
            const FootNote('다음 단계 안내'),
          ]),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('어른 식비'), findsOneWidget);
    });
  }
}
