import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../domain/finance_models.dart';
import '../../domain/plan_edit.dart';

/// 시트 공통 바탕: 위 둥근 모서리, 키보드만큼 올라옴, 제목 한 줄.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(AppGap.page, AppGap.md, AppGap.page, AppGap.md + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: AppText.titleLg),
            const SizedBox(height: AppGap.md),
            ...children,
          ]),
        ),
      );
}

/// 작은 입력 칸 라벨 + 위젯.
class SheetField extends StatelessWidget {
  const SheetField(this.label, this.child, {super.key});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppGap.cozy),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.caption.copyWith(color: context.palette.textMuted)),
          const SizedBox(height: AppGap.xs),
          child,
        ]),
      );
}

Future<bool> confirmDelete(BuildContext context, String what) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$what 지울까요?', style: AppText.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('지우기', style: AppText.bodyStrong.copyWith(color: c.palette.over))),
        ],
      ),
    ) ??
    false;

/// 고정지출 항목 편집(또는 [item] 이 null 이면 추가) 시트. 구분·지출 분류는 있는 것 중에서 고르기만 한다.
Future<void> showPlanItemSheet(BuildContext context, {PlanItem? item, required Plan plan, String? initialGroup}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlanItemSheet(item: item, plan: plan, initialGroup: initialGroup),
    );

class _PlanItemSheet extends ConsumerStatefulWidget {
  const _PlanItemSheet({required this.item, required this.plan, this.initialGroup});
  final PlanItem? item;
  final Plan plan;
  final String? initialGroup;

  @override
  ConsumerState<_PlanItemSheet> createState() => _PlanItemSheetState();
}

class _PlanItemSheetState extends ConsumerState<_PlanItemSheet> {
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _amount = TextEditingController(text: widget.item == null ? '' : '${widget.item!.monthlyAmount}');
  late final _payment = TextEditingController(text: widget.item?.payment ?? '');
  late final _payDay = TextEditingController(text: widget.item?.payDayText ?? '');
  late String? _accountId = widget.item?.accountId;
  String? _group, _category;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final cats = widget.plan.categories;
    final start = cats.where((c) => c.group == widget.initialGroup).firstOrNull ?? cats.firstOrNull;
    _group = start?.group;
    _category = start?.category;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _payment.dispose();
    _payDay.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
      if (mounted) Navigator.pop(context);
    } on PlanEditError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '저장하지 못했어요 ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    final amount = int.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amount == null || amount < 0) {
      setState(() => _error = '월 금액을 원 단위 숫자로 넣어 주세요');
      return;
    }
    final fields = PlanItemFields(
      monthlyAmount: amount,
      payment: _payment.text,
      accountId: _accountId,
      payDayText: _payDay.text,
    );
    final actions = ref.read(planActionsProvider);
    final item = widget.item;
    if (item != null) {
      _run(() => actions.update(item.id, fields));
    } else {
      if (_group == null || _category == null) {
        setState(() => _error = '구분·지출 분류를 골라 주세요');
        return;
      }
      _run(() => actions.add(_group!, _category!, _name.text, fields));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = widget.item;
    final accounts = ref.watch(accountsProvider).value ?? const <AccountRef>[];
    final payments = {for (final i in widget.plan.items) if (i.payment.isNotEmpty) i.payment}.toList();
    final groups = {for (final c in widget.plan.categories) c.group}.toList();
    final cats = [for (final c in widget.plan.categories) if (c.group == _group) c.category];

    return SheetFrame(title: item == null ? '고정지출 추가' : item.name, children: [
      if (item != null) Text('${item.group} · ${item.category}', style: AppText.caption.copyWith(color: p.textSub)),
      if (item == null) ...[
        SheetField('구분', _chips(groups, _group, (g) => setState(() {
              _group = g;
              _category = widget.plan.categories.firstWhere((c) => c.group == g).category;
            }))),
        SheetField('지출 분류', _chips(cats, _category, (c) => setState(() => _category = c))),
        SheetField('이름', TextField(controller: _name, style: AppText.body, decoration: const InputDecoration(hintText: '예: 항목 이름'))),
      ],
      SheetField(
        '월 계획 금액 (원)',
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
          style: AppText.body.tnum,
          decoration: const InputDecoration(hintText: '0'),
        ),
      ),
      SheetField('결제 수단(카드)', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _payment, style: AppText.body, decoration: const InputDecoration(hintText: '예: 가나다카드')),
        if (payments.isNotEmpty) ...[
          const SizedBox(height: AppGap.xs),
          ChipBar(children: [
            for (final s in payments) ActionChip(label: Text(s), onPressed: () => setState(() => _payment.text = s)),
          ]),
        ],
      ])),
      SheetField('출금 통장', ChipBar(children: [
        ChoiceChip(label: const Text('없음'), selected: _accountId == null, onSelected: (_) => setState(() => _accountId = null)),
        for (final a in accounts)
          ChoiceChip(label: Text(a.name), selected: _accountId == a.id, onSelected: (_) => setState(() => _accountId = a.id)),
        // 목록에 없는(지운) 통장 id 를 가진 항목도 값이 사라지지 않게 보여 준다.
        if (_accountId != null && !accounts.any((a) => a.id == _accountId))
          ChoiceChip(label: const Text('기존 통장'), selected: true, onSelected: (_) {}),
      ])),
      SheetField('결제일', TextField(controller: _payDay, style: AppText.body, decoration: const InputDecoration(hintText: '예: 매월 21일'))),
      if (_error != null) Padding(
        padding: const EdgeInsets.only(bottom: AppGap.sm),
        child: Text(_error!, style: AppText.caption.copyWith(color: p.over)),
      ),
      Row(children: [
        if (item != null)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    if (await confirmDelete(context, '‘${item.name}’ 항목을')) {
                      _run(() => ref.read(planActionsProvider).delete(item.id));
                    }
                  },
            child: Text('삭제', style: AppText.bodyStrong.copyWith(color: p.over)),
          ),
        const Spacer(),
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('취소')),
        const SizedBox(width: AppGap.sm),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('저장')),
      ]),
    ]);
  }

  Widget _chips(List<String> values, String? selected, ValueChanged<String> onPick) => ChipBar(children: [
        for (final v in values) ChoiceChip(label: Text(v), selected: selected == v, onSelected: (_) => onPick(v)),
      ]);
}
