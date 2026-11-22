import 'package:flutter/material.dart';

import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import '../../domain/diagnosis.dart';
import '../../domain/finance_models.dart';
import '../../domain/savings_simulator.dart';

/// S8 절감 시뮬레이터 — 항목을 고르고 줄일 비율/금액을 정하면 월·연 효과를 계획과 비교해 보여 준다.
/// 화면 안 상태일 뿐 아무것도 저장하지 않는다(계획은 그대로).
class SimulatorCard extends StatefulWidget {
  const SimulatorCard({super.key, required this.plan, required this.diagnosis});
  final Plan plan;
  final DiagnosisResult diagnosis;

  @override
  State<SimulatorCard> createState() => _SimulatorCardState();
}

class _SimulatorCardState extends State<SimulatorCard> {
  ReductionMode _mode = ReductionMode.percent;

  /// 고른 분류 → 줄일 값(percent 면 0~100, amount 면 원).
  final Map<String, int> _picked = {};

  static const _defaultPercent = 10;
  static const _amountStep = 10000;

  /// 줄여 볼 수 있는 항목: 생활비 묶음(키 `g:`) + 생활비 묶음에 속하지 않는 계획 항목(키 `i:`). 고정 구분(대출·저축)은 뺀다. 큰 순.
  Map<String, int> _candidates = const {};
  Map<String, String> _labels = const {};

  void _build() {
    const rules = DiagnosisRules();
    final amounts = <String, int>{}, labels = <String, String>{};
    for (final e in widget.plan.livingPlan.entries) {
      if (e.value <= 0) continue;
      amounts['g:${e.key}'] = e.value;
      labels['g:${e.key}'] = livingLabels[e.key] ?? e.key;
    }
    for (final i in widget.plan.items) {
      if (i.living != null || i.monthlyAmount <= 0 || rules.fixedGroups.contains(i.group)) continue;
      amounts['i:${i.id}'] = i.monthlyAmount;
      labels['i:${i.id}'] = i.name;
    }
    final list = amounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    _candidates = {for (final e in list) e.key: e.value};
    _labels = labels;
  }

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(SimulatorCard old) {
    super.didUpdateWidget(old);
    if (old.plan != widget.plan) _build();
  }

  int _initial(int plan) => _mode == ReductionMode.percent ? _defaultPercent : (plan ~/ 10 ~/ _amountStep * _amountStep).clamp(_amountStep, plan);

  void _toggle(String key, int plan) => setState(() {
        if (_picked.containsKey(key)) {
          _picked.remove(key);
        } else {
          _picked[key] = _initial(plan);
        }
      });

  void _setMode(ReductionMode m) => setState(() {
        _mode = m;
        final c = _candidates;
        for (final k in _picked.keys.toList()) {
          _picked[k] = _initial(c[k] ?? 0);
        }
      });

  void _pickCut() => setState(() {
        final c = _candidates;
        _picked.clear();
        for (final r in widget.diagnosis.cut) {
          final k = r.scope == DiagnosisScope.living ? 'g:${r.key}' : 'i:${r.key}';
          if (c.containsKey(k)) _picked[k] = _initial(c[k]!);
        }
      });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cands = _candidates;
    final total = widget.plan.total;
    final sim = simulateSavings([
      for (final e in _picked.entries)
        if (cands.containsKey(e.key)) SimInput(key: e.key, plan: cands[e.key]!, mode: _mode, value: e.value),
    ], planTotal: total);

    return SectionCard(
      title: '절감 시뮬레이터',
      trailing: '계산만 해요 · 계획은 안 바뀌어요',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SegmentedButton<ReductionMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ReductionMode.percent, label: Text('비율')),
              ButtonSegment(value: ReductionMode.amount, label: Text('금액')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => _setMode(s.first),
          ),
          const Spacer(),
          if (widget.diagnosis.cut.isNotEmpty)
            TextButton(onPressed: _pickCut, child: const Text('줄일 것 고르기')),
          if (_picked.isNotEmpty) TextButton(onPressed: () => setState(_picked.clear), child: const Text('비우기')),
        ]),
        ChipBar(children: [
          for (final e in cands.entries)
            FilterChip(
              label: Text('${_labels[e.key]} ${man(e.value)}'),
              selected: _picked.containsKey(e.key),
              onSelected: (_) => _toggle(e.key, e.value),
            ),
        ]),
        for (final e in _picked.entries)
          if (cands.containsKey(e.key)) _slider(context, e.key, cands[e.key]!, e.value),
        if (_picked.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppGap.sm),
            child: Text('줄여 볼 항목을 골라 보세요', style: AppText.caption.copyWith(color: p.textMuted)),
          )
        else ...[
          const Divider(height: AppGap.lg),
          Row(children: [
            Expanded(child: Text('월 절감', style: AppText.body)),
            MoneyText(man(sim.monthly), style: AppText.numMd, tabular: false),
          ]),
          const SizedBox(height: AppGap.xs),
          Row(children: [
            Expanded(child: Text('연 절감', style: AppText.body)),
            MoneyText(man(sim.annual), style: AppText.numMd, tabular: false),
          ]),
          const SizedBox(height: AppGap.xs),
          Text(
            '월 계획 ${man(total)} → ${man(sim.newPlanTotal)} (${(sim.shareOfPlan * 100).toStringAsFixed(1)}% 감소)',
            style: AppText.caption.copyWith(color: p.textSub).tnum,
          ),
        ],
      ]),
    );
  }

  Widget _slider(BuildContext context, String key, int plan, int value) {
    final p = context.palette;
    final isPct = _mode == ReductionMode.percent;
    final max = isPct ? 100.0 : plan.toDouble();
    final divisions = isPct ? 20 : (plan ~/ _amountStep).clamp(1, 200);
    final saved = isPct ? plan * value ~/ 100 : value;
    return Padding(
      padding: const EdgeInsets.only(top: AppGap.xs),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_labels[key] ?? key, style: AppText.body, overflow: TextOverflow.ellipsis)),
          Text(
            '${isPct ? '$value%' : man(value)} · 월 −${man(saved)} → ${man(plan - saved)}',
            style: AppText.caption.copyWith(color: p.textSub).tnum,
          ),
        ]),
        Slider(
          value: value.toDouble().clamp(0, max),
          max: max,
          divisions: divisions,
          onChanged: (v) => setState(() => _picked[key] = isPct ? v.round() : (v / _amountStep).round() * _amountStep),
        ),
      ]),
    );
  }
}
