import 'package:flutter/material.dart';

import '../format/won.dart';
import 'tokens.dart';

/// 카드 한 장(흰 바탕, 둥근 모서리 14, 그림자 없음). 카드 사이 간격 8(위아래 4씩).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(AppGap.md)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: AppGap.page, vertical: AppGap.xs),
        padding: padding,
        decoration: BoxDecoration(color: context.palette.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: child,
      );
}

/// 구획 카드(7.1 SectionCard): 머리(제목 · 오른쪽 요약)가 카드 **안** 첫 줄. 카드 밖 제목 줄을 없애 위아래 공간을 아낀다.
/// [list] = 행 목록(AmountRow)을 담는 카드. 행이 좌우 4씩 들여 쓰므로 카드 안쪽은 8 — 글자 시작선은 어느 카드든 12로 같다.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.list = false});
  final String? title;
  final String? trailing;
  final Widget child;
  final bool list;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final inset = list ? AppGap.sm : AppGap.md;
    final head = title == null
        ? null
        : Padding(
            padding: EdgeInsets.symmetric(horizontal: list ? AppGap.xs : 0),
            child: SizedBox(
              height: AppSize.sectionHead,
              child: Row(children: [
                Flexible(child: Text(title!, style: AppText.title, overflow: TextOverflow.ellipsis)),
                if (trailing != null) ...[
                  const SizedBox(width: AppGap.sm),
                  Expanded(
                    child: Text(trailing!,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(color: p.textSub)),
                  ),
                ],
              ]),
            ),
          );
    return Panel(
      padding: EdgeInsets.fromLTRB(inset, head == null ? (list ? AppGap.xs : AppGap.md) : AppGap.sm, inset,
          list ? AppGap.xs : AppGap.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ?head,
        if (head != null && !list) const SizedBox(height: AppGap.xs),
        child,
      ]),
    );
  }
}

/// 금액 글자(7.13 MoneyText): 숫자는 표 숫자, 끝의 단위(원·만·억)는 한 단계 작게 `textSub` — 숫자가 먼저 읽히게(4.2).
class MoneyText extends StatelessWidget {
  const MoneyText(this.text, {super.key, this.style = AppText.bodyStrong, this.color, this.tabular = true});
  final String text;
  final TextStyle style;
  final Color? color;

  /// 혼자 크게 보이는 KPI 숫자는 false(비례폭).
  final bool tabular;

  static final _unit = RegExp(r'^(.*\d)(원|만|억)$');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = style.copyWith(color: color ?? p.ink, fontFeatures: tabular ? AppText.tabular : null);
    final m = _unit.firstMatch(text);
    if (m == null) return Text(text, style: base, maxLines: 1);
    final unit = ((style.fontSize ?? 13) >= (AppText.numMd.fontSize ?? 18) ? AppText.body : AppText.caption)
        .copyWith(fontWeight: FontWeight.w500, color: p.textSub);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: m.group(1)),
        TextSpan(text: m.group(2), style: unit),
      ]),
      style: base,
      maxLines: 1,
    );
  }
}

/// 요약 숫자 하나. 숫자 먼저, 라벨은 작게. 숫자에 색을 줄 때는 [sub] 에 글자로도 판단을 쓴다(색만으로 전하지 않기).
class KpiTile extends StatelessWidget {
  const KpiTile({super.key, required this.label, required this.value, this.sub, this.valueColor});
  final String label, value;
  final String? sub;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppGap.md, vertical: AppGap.cozy),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.caption.copyWith(color: p.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppGap.xxs),
          MoneyText(value, style: AppText.numMd, color: valueColor, tabular: false),
          if (sub != null)
            Text(sub!,
                style: AppText.caption.copyWith(color: valueColor ?? p.textSub).tnum,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

/// 계획 대비 실제 한 줄(7.4): 이름 · 쓴 금액 / 계획 · 판단(초과 / 남은 / 계획대로) + 진행 바(계획 눈금, 넘친 부분만 빨강).
class BudgetRow extends StatelessWidget {
  const BudgetRow({super.key, required this.name, required this.actual, required this.plan, this.detail});
  final String name;
  final int actual, plan;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ratio = plan <= 0 ? 1.0 : actual / plan;
    final over = plan > 0 && actual > plan * 1.05;
    final under = plan > 0 && actual < plan * 0.95;
    final diff = actual - plan;
    // 여유는 색을 바꾸지 않는다(7.4) — 달 중간의 "덜 씀"을 초록으로 칭찬하지 않게.
    final judge = plan <= 0
        ? ''
        : over
            ? '${man(diff)} 초과'
            : under
                ? '남은 ${man(-diff)}'
                : '계획대로';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppGap.snug),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name, style: AppText.body, overflow: TextOverflow.ellipsis)),
          Text('${man(actual)} / ${man(plan)}', style: AppText.label.copyWith(color: p.ink).tnum),
          SizedBox(
            width: AppSize.numCol,
            child: Text(
              judge,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: AppText.caption.copyWith(color: over ? p.over : p.textSub).tnum,
            ),
          ),
        ]),
        const SizedBox(height: AppGap.xs),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final scale = ratio > 1 ? 1 / ratio : 1.0; // 넘치면 계획 눈금을 안쪽으로
          final planX = (w * scale).clamp(0.0, w);
          final fill = (w * (ratio > 1 ? 1.0 : ratio)).clamp(0.0, w);
          final r = BorderRadius.circular(AppRadius.xs);
          return SizedBox(
            height: AppSize.progress,
            child: Stack(children: [
              Container(decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: r)),
              Container(
                  width: over ? planX : fill,
                  decoration: BoxDecoration(color: p.textSub.withValues(alpha: AppAlpha.barFill), borderRadius: r)),
              if (over)
                Positioned(
                  left: planX,
                  child: Container(
                      width: (w - planX).clamp(0.0, w),
                      height: AppSize.progress,
                      decoration: BoxDecoration(color: p.overMark, borderRadius: r)),
                ),
              if (plan > 0)
                Positioned(
                  left: (planX - AppSize.planTick / 2).clamp(0.0, w - AppSize.planTick),
                  child: Container(width: AppSize.planTick, height: AppSize.progress, color: p.ink),
                ),
            ]),
          );
        }),
        if (detail != null) ...[
          const SizedBox(height: AppGap.xs),
          Text(detail!, style: AppText.caption.copyWith(color: p.textMuted)),
        ],
      ]),
    );
  }
}

/// ‹ 2026년 11월 › — 달 넘기기. 앱 바 자리(높이 44) 한 줄.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.months, required this.onChanged, this.note});
  final String month;
  final List<String> months;
  final ValueChanged<String> onChanged;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final i = months.indexOf(month);
    final y = month.substring(0, 4), m = int.parse(month.substring(5));
    return SizedBox(
      height: AppSize.appBar,
      child: Row(children: [
        const SizedBox(width: AppGap.xs),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: AppSize.navIcon,
          color: p.ink,
          onPressed: i > 0 ? () => onChanged(months[i - 1]) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('$y년 $m월', style: AppText.title.tnum),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: AppSize.navIcon,
          color: p.ink,
          onPressed: i >= 0 && i < months.length - 1 ? () => onChanged(months[i + 1]) : null,
          icon: const Icon(Icons.chevron_right),
        ),
        const Spacer(),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(right: AppGap.page),
            child: Text(note!, style: AppText.caption.copyWith(color: p.textSub)),
          ),
      ]),
    );
  }
}

/// 금액 한 줄 행(7.5): 이름 · 보조줄 · 금액(표 숫자, 오른쪽 정렬). 줄무늬 없이 아래 1px 선만, 마지막 행은 [divider] false.
/// 좌우 4씩 들여 쓴다 — 선택 표시 바탕이 글자에 붙지 않고, 선택해도 글자 위치가 그대로다.
class AmountRow extends StatelessWidget {
  const AmountRow({
    super.key,
    required this.title,
    this.sub,
    required this.amount,
    this.amountColor,
    this.leading,
    this.onTap,
    this.selected = false,
    this.dimmed = false,
    this.divider = true,
  });
  final String title;
  final String? sub;
  final String amount;
  final Color? amountColor;
  final Widget? leading;

  /// 누르면 이 항목에 포커스(다시 누르면 해제). null 이면 누를 수 없는 줄.
  final VoidCallback? onTap;
  final bool selected;

  /// 다른 항목에 포커스가 있을 때 흐리게.
  final bool dimmed;

  /// 아래 1px 선. 목록의 마지막 행은 끈다.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final row = _row(context);
    if (onTap == null) return row;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppRadius.md), child: row);
  }

  Widget _row(BuildContext context) {
    final p = context.palette;
    return Opacity(
      opacity: dimmed ? AppAlpha.dimmed : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSize.row),
        padding: const EdgeInsets.symmetric(vertical: AppGap.snug, horizontal: AppGap.xs),
        // 선택은 판단이 아니므로 의미색(info) 대신 무채색 면.
        decoration: BoxDecoration(
          color: selected ? p.surfaceMuted : null,
          borderRadius: selected ? BorderRadius.circular(AppRadius.md) : null,
          border: selected || !divider ? null : Border(bottom: BorderSide(color: p.line)),
        ),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppGap.sm)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: selected ? AppText.bodyStrong : AppText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (sub != null)
                Text(sub!,
                    style: AppText.caption.copyWith(color: p.textSub).tnum, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: AppGap.sm),
          MoneyText(amount, color: amountColor),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(left: AppGap.xxs),
              child: Icon(selected ? Icons.close : Icons.chevron_right, size: AppSize.icon, color: selected ? p.ink : p.textMuted),
            ),
        ]),
      ),
    );
  }
}
