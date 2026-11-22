import 'package:flutter/material.dart';

import 'tokens.dart';

/// 한 줄짜리 화면 머리(높이 44, 제목 14 w700). 큰 대제목·배너는 쓰지 않는다.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: AppSize.appBar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
          child: Row(children: [
            Expanded(child: Text(title, style: AppText.title)),
            ?trailing,
          ]),
        ),
      );
}

/// 아직 만들지 않은 화면 자리.
class ComingSoon extends StatelessWidget {
  const ComingSoon(this.title, this.what, {super.key});
  final String title;
  final String what;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title),
          Expanded(
            child: Center(
              child: Text(what, textAlign: TextAlign.center, style: AppText.body.copyWith(color: context.palette.textSub)),
            ),
          ),
        ],
      );
}

/// 화면 아래 한 줄 안내(다음 단계 예고 등). 카드 밖, 글자 시작선은 카드 안 글자와 같다.
class FootNote extends StatelessWidget {
  const FootNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppGap.page + AppGap.md, AppGap.sm, AppGap.page, AppGap.sm),
        child: Text(text, style: AppText.caption.copyWith(color: context.palette.textMuted)),
      );
}

/// 필터 칩 한 줄(7.3): 가로로 밀어 보는 한 줄, 줄바꿈 없음. 칩 모양은 테마(chipTheme)가 정한다.
class ChipBar extends StatelessWidget {
  const ChipBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppGap.page, vertical: AppGap.xs),
        child: Row(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppGap.sm),
            children[i],
          ],
        ]),
      );
}

/// 사람 이름표 — 이름 옆 작은 배지. 사람은 색이 아니라 글자 + `ink` 테두리로 구분한다(DESIGN_SYSTEM 3.5):
/// 빨강·파랑 사람색은 "초과"·"안내"와 겹쳐 읽혔다.
class OwnerBadge extends StatelessWidget {
  const OwnerBadge({super.key, required this.name, required this.owner});
  final String name;

  /// 사람 칸 키('a' = 파랑, 'b' = 빨강). 사용자 지정, Ninedogs 와 같은 모양.
  final String owner;

  @override
  Widget build(BuildContext context) {
    final c = PersonColors.of(context, owner);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppGap.xs, vertical: AppGap.xxs / 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: PersonColors.badgeAlpha),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(name, style: AppText.micro.copyWith(color: c, fontWeight: FontWeight.w700)),
    );
  }
}
