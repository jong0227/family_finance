import 'package:flutter/material.dart';

import 'tokens.dart';

/// 한 줄짜리 화면 머리(높이 44). 큰 대제목·배너는 쓰지 않는다.
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
            Expanded(child: Text(title, style: Theme.of(context).appBarTheme.titleTextStyle)),
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
              child: Text(what, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ],
      );
}

/// 사람 이름표 — 이름 오른쪽 위에 붙는 작은 색 배지 (Ninedogs 와 같은 모양).
class OwnerBadge extends StatelessWidget {
  const OwnerBadge({super.key, required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(4)),
        child: Text(name, style: TextStyle(fontSize: 10, height: 1.3, fontWeight: FontWeight.w700, color: color)),
      );
}
