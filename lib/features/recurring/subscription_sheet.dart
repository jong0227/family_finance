import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ninedogs_core/ninedogs_core.dart';

import '../../app/session.dart';
import '../../core/design/tokens.dart';
import '../../core/design/components.dart';
import '../../domain/subscription_edit.dart';
import 'plan_item_sheet.dart';

String _ymd(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 구독 편집([sub] 있음) / 추가([sub] null) 시트. 쓰기는 공유 계약 가드를 거친다.
Future<void> showSubscriptionSheet(BuildContext context, {Subscription? sub}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SubscriptionSheet(sub: sub),
    );

class _SubscriptionSheet extends ConsumerStatefulWidget {
  const _SubscriptionSheet({required this.sub});
  final Subscription? sub;

  @override
  ConsumerState<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<_SubscriptionSheet> {
  late final _name = TextEditingController(text: widget.sub?.name ?? '');
  late final _price = TextEditingController(text: widget.sub?.currentPrice.inputText ?? '');
  late final _payment = TextEditingController(text: widget.sub?.paymentMethod ?? '');
  late final _memo = TextEditingController(text: widget.sub?.memo ?? '');
  late BillingCycle _cycle = widget.sub?.cycle ?? BillingCycle.monthly;
  late String? _owner = widget.sub?.owner;
  late DateTime? _next = widget.sub?.nextBillingDate();
  bool _nextTouched = false;
  bool _correction = false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _payment.dispose();
    _memo.dispose();
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
    } on ContractTooNewException {
      if (mounted) setState(() => _error = '다른 앱이 더 새 버전으로 저장해서 이 앱은 쓸 수 없어요. 앱을 업데이트해 주세요');
    } catch (e) {
      if (mounted) setState(() => _error = '저장하지 못했어요 ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    final sub = widget.sub;
    final currency = sub?.currency ?? Money.krw;
    final price = Money.tryParse(_price.text, currency: currency);
    if (price == null) {
      setState(() => _error = '금액을 숫자로 넣어 주세요');
      return;
    }
    final actions = ref.read(subscriptionActionsProvider);
    if (sub == null) {
      if (_name.text.trim().isEmpty) {
        setState(() => _error = '이름을 넣어 주세요');
        return;
      }
      final s = newSubscription(
        id: newSubscriptionId(),
        name: _name.text,
        wonAmount: price.minor,
        cycle: _cycle,
        startedAt: DateTime.now(),
        nextBilling: _next,
        owner: _owner,
        memo: _memo.text,
        paymentMethod: _payment.text,
      );
      _run(() => actions.save(s));
    } else {
      final s = editSubscription(
        sub,
        price: price,
        cycle: _cycle,
        priceCorrection: _correction,
        nextBilling: _nextTouched ? _next : null,
        owner: _owner,
        clearOwner: _owner == null,
        memo: _memo.text,
        clearMemo: _memo.text.trim().isEmpty,
        paymentMethod: _payment.text,
        clearPayment: _payment.text.trim().isEmpty,
      );
      _run(() => actions.save(s));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _next ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: '다음 결제일',
    );
    if (d == null) return;
    setState(() {
      _next = d;
      _nextTouched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sub = widget.sub;
    final people = ref.watch(peopleProvider).value ?? People.defaults;
    final readOnly = ref.watch(subscriptionsReadOnlyProvider);
    final currency = sub?.currency ?? Money.krw;
    final parsed = Money.tryParse(_price.text, currency: currency);
    final priceChanged = sub != null && parsed != null && parsed != sub.currentPrice;

    return SheetFrame(title: sub == null ? '구독 추가' : sub.name, children: [
      if (readOnly) const ReadOnlyBanner(),
      if (sub == null)
        SheetField('이름', TextField(controller: _name, style: AppText.body, decoration: const InputDecoration(hintText: '예: OTT-A'))),
      SheetField(
        currency == Money.krw ? '금액 (원)' : '금액 ($currency)',
        TextField(
          controller: _price,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
          style: AppText.body.tnum,
        ),
      ),
      if (priceChanged)
        SheetField(
          '금액이 바뀌었어요',
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('오늘부터 변경')),
              ButtonSegment(value: true, label: Text('잘못 적어서 정정')),
            ],
            selected: {_correction},
            onSelectionChanged: (s) => setState(() => _correction = s.first),
          ),
        ),
      SheetField('결제 주기', ChipBar(children: [
        for (final c in BillingCycle.values) ChoiceChip(label: Text(c.label), selected: _cycle == c, onSelected: (_) => setState(() => _cycle = c)),
      ])),
      SheetField('다음 결제일', Row(children: [
        Text(_next == null ? '정하지 않음' : _ymd(_next!), style: AppText.body.tnum),
        const SizedBox(width: AppGap.sm),
        TextButton(onPressed: _pickDate, child: const Text('고르기')),
      ])),
      SheetField('주인', ChipBar(children: [
        ChoiceChip(label: const Text('공동'), selected: _owner == null, onSelected: (_) => setState(() => _owner = null)),
        for (final k in People.slots)
          ChoiceChip(label: Text(people.nameOf(k)), selected: _owner == k, onSelected: (_) => setState(() => _owner = k)),
      ])),
      SheetField('결제 수단', TextField(controller: _payment, style: AppText.body, decoration: const InputDecoration(hintText: '예: 가나다카드'))),
      SheetField('메모', TextField(controller: _memo, style: AppText.body, maxLines: 2, minLines: 1)),
      if (_error != null)
        Padding(padding: const EdgeInsets.only(bottom: AppGap.sm), child: Text(_error!, style: AppText.caption.copyWith(color: p.over))),
      Row(children: [
        if (sub != null)
          TextButton(
            onPressed: _busy || readOnly
                ? null
                : () async {
                    if (await confirmDelete(context, '‘${sub.name}’ 구독을')) {
                      _run(() => ref.read(subscriptionActionsProvider).delete(sub.id));
                    }
                  },
            child: Text('삭제', style: AppText.bodyStrong.copyWith(color: readOnly ? p.textMuted : p.over)),
          ),
        const Spacer(),
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('취소')),
        const SizedBox(width: AppGap.sm),
        FilledButton(onPressed: _busy || readOnly ? null : _save, child: const Text('저장')),
      ]),
    ]);
  }
}

/// 서버에 더 새로운 계약 버전이 있을 때 구독 화면 위에 띄우는 읽기 전용 띠.
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppGap.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppGap.md, vertical: AppGap.sm),
      decoration: BoxDecoration(color: p.infoBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text('구독 데이터가 더 새로운 버전이에요. 이 앱을 업데이트하기 전까지 구독은 읽기만 돼요',
          style: AppText.caption.copyWith(color: p.info)),
    );
  }
}
