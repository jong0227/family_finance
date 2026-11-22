import 'package:flutter/material.dart';

import '../format/won.dart';
import 'tokens.dart';

const _tabular = [FontFeature.tabularFigures()];

/// 카드 한 장(흰 바탕, 둥근 모서리 14, 그림자 없음).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(AppGap.md)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: AppGap.page, vertical: AppGap.xs),
        padding: padding,
        decoration: BoxDecoration(color: context.palette.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: child,
      );
}

/// 구획 제목 + 오른쪽 보조 글.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGap.page, AppGap.lg, AppGap.page, AppGap.xs),
      child: Row(children: [
        Expanded(child: Text(title, style: t.titleMedium)),
        if (trailing != null) Text(trailing!, style: t.labelMedium),
      ]),
    );
  }
}

/// 요약 숫자 하나. 숫자 먼저, 라벨은 작게.
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
        padding: const EdgeInsets.symmetric(horizontal: AppGap.md, vertical: AppGap.sm + 2),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: p.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: valueColor ?? p.ink, fontFeatures: _tabular)),
          if (sub != null) Text(sub!, style: TextStyle(fontSize: 11, color: p.textSub)),
        ]),
      ),
    );
  }
}

/// 계획 대비 실제 한 줄: 이름 · 막대(계획선 표시, 넘으면 빨강) · 실제/계획 · 차이.
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
    final color = over ? p.over : (under ? p.under : p.textSub);
    final diff = actual - plan;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppGap.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          Text('${man(actual)} / ${man(plan)}', style: TextStyle(fontSize: 12, color: p.textSub, fontFeatures: _tabular)),
          const SizedBox(width: AppGap.sm),
          SizedBox(
            width: 58,
            child: Text(
              plan <= 0 ? '' : '${diff > 0 ? '+' : ''}${man(diff)}',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, fontFeatures: _tabular),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final scale = ratio > 1 ? 1 / ratio : 1.0; // 넘치면 계획선을 안쪽으로
          final planX = (w * scale).clamp(0.0, w);
          final fill = (w * (ratio > 1 ? 1.0 : ratio)).clamp(0.0, w);
          return SizedBox(
            height: 8,
            child: Stack(children: [
              Container(decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: BorderRadius.circular(4))),
              Container(
                  width: over ? planX : fill,
                  decoration: BoxDecoration(color: p.textSub.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(4))),
              if (over)
                Positioned(
                  left: planX,
                  child: Container(
                      width: (w - planX).clamp(0.0, w),
                      height: 8,
                      decoration: BoxDecoration(color: p.over, borderRadius: BorderRadius.circular(4))),
                ),
              if (plan > 0) Positioned(left: (planX - 1).clamp(0.0, w - 2), child: Container(width: 2, height: 8, color: p.ink)),
            ]),
          );
        }),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(detail!, style: TextStyle(fontSize: 11, color: p.textMuted)),
        ],
      ]),
    );
  }
}

/// ‹ 2026년 11월 › — 달 넘기기.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.months, required this.onChanged, this.note});
  final String month;
  final List<String> months;
  final ValueChanged<String> onChanged;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final i = months.indexOf(month);
    final y = month.substring(0, 4), m = int.parse(month.substring(5));
    final t = Theme.of(context).appBarTheme.titleTextStyle;
    return SizedBox(
      height: AppSize.appBar,
      child: Row(children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: i > 0 ? () => onChanged(months[i - 1]) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('$y년 $m월', style: t),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: i >= 0 && i < months.length - 1 ? () => onChanged(months[i + 1]) : null,
          icon: const Icon(Icons.chevron_right),
        ),
        const Spacer(),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(right: AppGap.page),
            child: Text(note!, style: Theme.of(context).textTheme.labelMedium),
          ),
      ]),
    );
  }
}

/// 금액 한 줄 행(이름 · 보조 · 금액). 줄무늬 없이 아래 선만.
class AmountRow extends StatelessWidget {
  const AmountRow({super.key, required this.title, this.sub, required this.amount, this.amountColor, this.leading});
  final String title;
  final String? sub;
  final String amount;
  final Color? amountColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.row),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: AppGap.sm)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.bodyMedium, overflow: TextOverflow.ellipsis),
            if (sub != null) Text(sub!, style: t.labelSmall, overflow: TextOverflow.ellipsis),
          ]),
        ),
        Text(amount,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: amountColor ?? p.ink, fontFeatures: _tabular)),
      ]),
    );
  }
}
