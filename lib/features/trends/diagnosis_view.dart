import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import '../../domain/diagnosis.dart';
import '../../domain/finance_models.dart';
import 'savings_simulator_card.dart';

/// 진단 — 줄일 것 / 여유 있는 것 (SCREENS 2.4) + 절감 시뮬레이터(S8).
/// 근거: 완전한 달 최근 6개월(진행 중인 달 제외)의 평균과 계획 비교. 근거 기간은 행마다 글자로 보여 준다.
class DiagnosisView extends ConsumerWidget {
  const DiagnosisView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider).value;
    final result = ref.watch(diagnosisProvider);
    final p = context.palette;
    if (plan == null || result == null) {
      return Center(child: Text('계획이 있어야 진단할 수 있어요', style: AppText.body.copyWith(color: p.textSub)));
    }
    final cut = result.cut, slack = result.slack, fixed = result.fixed;
    final insufficient = result.rows.where((r) => r.verdict == Verdict.insufficient && !r.fixed).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: AppGap.xl),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppGap.page, vertical: AppGap.xs),
          child: Text(
            '줄일 것 ${cut.length}개 '
            '+${man(result.cutTotal)} · 여유 ${slack.length}개 '
            '${man(-result.slackTotal)}',
            style: AppText.label.copyWith(color: p.textSub).tnum,
          ),
        ),
        _Group(
          title: '줄일 것',
          trailing: '생활비는 6개월 근거 · 항목은 최근 실제 기준',
          rows: cut,
          empty: '꾸준히 초과한 항목이 없어요',
          cut: true,
        ),
        _Group(
          title: '여유 있음',
          trailing: '계획보다 꾸준히 적게 쓴 것',
          rows: slack,
          empty: '꾸준히 여유 있는 항목이 없어요',
          cut: false,
        ),
        if (insufficient.isNotEmpty)
          _Group(
            title: '판정 보류',
            trailing: '완전한 달이 3개월 미만',
            rows: insufficient,
            empty: '',
            cut: false,
          ),
        if (fixed.isNotEmpty)
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: AppGap.md, vertical: AppGap.xs),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                dense: true,
                title: Text('고정이라 판정에서 뺀 ${fixed.length}개', style: AppText.label.copyWith(color: p.textSub)),
                children: [
                  for (final (i, r) in fixed.indexed)
                    _DxRow(row: r, cut: false, divider: i < fixed.length - 1, showVerdict: false),
                ],
              ),
            ),
          ),
        SimulatorCard(plan: plan, diagnosis: result),
        const FootNote('현재 계획을 기준으로 지난 달들과 비교해요 · 일회성(100만+)은 제외'),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.trailing, required this.rows, required this.empty, required this.cut});
  final String title, trailing, empty;
  final List<DiagnosisRow> rows;
  final bool cut;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      title: title,
      trailing: trailing,
      list: true,
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppGap.sm, horizontal: AppGap.xs),
              child: Text(empty, style: AppText.caption.copyWith(color: p.textMuted)),
            )
          : Column(children: [
              for (final (i, r) in rows.indexed) _DxRow(row: r, cut: cut, divider: i < rows.length - 1),
            ]),
    );
  }
}

/// 진단 한 줄: 이름 · 평균/계획 · 근거 기간 / 오른쪽 초과·여유 금액. 누르면 달별 금액.
class _DxRow extends StatefulWidget {
  const _DxRow({required this.row, required this.cut, required this.divider, this.showVerdict = true});
  final DiagnosisRow row;
  final bool cut, divider, showVerdict;

  @override
  State<_DxRow> createState() => _DxRowState();
}

class _DxRowState extends State<_DxRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = widget.row;
    final label = r.scope == DiagnosisScope.living ? (livingLabels[r.key] ?? r.key) : r.label;
    final amount = !widget.showVerdict || r.verdict == Verdict.insufficient
        ? man(r.average)
        : widget.cut
            ? '+${man(r.diff)}'
            : man(r.diff);
    final judged = widget.showVerdict && r.verdict != Verdict.insufficient;
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSize.row),
        padding: const EdgeInsets.symmetric(vertical: AppGap.snug, horizontal: AppGap.xs),
        decoration: BoxDecoration(border: widget.divider ? Border(bottom: BorderSide(color: p.line)) : null),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Row(children: [
                Flexible(child: Text(label, style: AppText.body, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (r.scope == DiagnosisScope.living) ...[
                  const SizedBox(width: AppGap.xs),
                  Text('생활비', style: AppText.micro.copyWith(color: p.textMuted)),
                ],
              ]),
            ),
            const SizedBox(width: AppGap.sm),
            MoneyText(amount, color: judged && widget.cut ? p.over : null),
            if (r.n > 0) Icon(_open ? Icons.expand_less : Icons.expand_more, size: AppSize.icon, color: p.textMuted),
          ]),
          Text('평균 ${man(r.average)} / 계획 ${man(r.plan)} (${(r.ratio * 100).round()}%)',
              style: AppText.caption.copyWith(color: p.textSub).tnum),
          Text(r.evidence, style: AppText.caption.copyWith(color: p.textMuted).tnum),
          if (_open && r.n > 0) ...[
            const SizedBox(height: AppGap.xs),
            Wrap(spacing: AppGap.md, runSpacing: AppGap.xxs, children: [
              for (var i = 0; i < r.n; i++)
                Text(
                  '${int.parse(r.months[i].substring(5))}월 ${man(r.actuals[i])}',
                  style: AppText.caption
                      .copyWith(color: r.actuals[i] > r.plan * 1.05 ? p.over : p.textSub, fontWeight: FontWeight.w500)
                      .tnum,
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}
