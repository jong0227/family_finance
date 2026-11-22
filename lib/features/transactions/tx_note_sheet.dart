import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/tokens.dart';
import '../../core/format/won.dart';
import '../../domain/finance_models.dart';
import '../../domain/tx_note.dart';
import '../recurring/plan_item_sheet.dart' show SheetField, SheetFrame;

/// 거래 상세 + 부부 메모·태그(S9). 원본은 보기만, 메모·태그만 고친다.
Future<void> showTxNoteSheet(BuildContext context, Tx tx) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TxNoteSheet(tx: tx),
    );

class _TxNoteSheet extends ConsumerStatefulWidget {
  const _TxNoteSheet({required this.tx});
  final Tx tx;

  @override
  ConsumerState<_TxNoteSheet> createState() => _TxNoteSheetState();
}

class _TxNoteSheetState extends ConsumerState<_TxNoteSheet> {
  late final _note = TextEditingController(text: widget.tx.note);
  late final _tags = TextEditingController(text: widget.tx.userTags.join(', '));
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(financeNoteActionsProvider).saveNote(widget.tx.key, _note.text, parseTagInput(_tags.text));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장하지 못했어요\n$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tx;
    final p = context.palette;
    final me = ref.read(financeNoteActionsProvider).myUid;
    return SheetFrame(title: t.merchant, children: [
      Text(
        '${t.date} ${t.time} · ${txWon(t.amount)} · ${t.kind == '소비' ? t.category : t.kind} · ${t.payment}',
        style: AppText.caption.copyWith(color: p.textSub).tnum,
      ),
      if (t.noteBy != null)
        Padding(
          padding: const EdgeInsets.only(top: AppGap.xs),
          child: Text('마지막 메모: ${t.noteBy == me ? '나' : '배우자'}', style: AppText.caption.copyWith(color: p.textMuted)),
        ),
      const SizedBox(height: AppGap.md),
      SheetField(
        '메모',
        TextField(
          controller: _note,
          maxLength: kNoteMaxLen,
          maxLines: 2,
          style: AppText.body,
          decoration: const InputDecoration(hintText: '예: 생일 선물, 환불 예정'),
        ),
      ),
      SheetField(
        '태그 (쉼표로 구분)',
        TextField(controller: _tags, style: AppText.body, decoration: const InputDecoration(hintText: '예: 선물, 환불예정')),
      ),
      const SizedBox(height: AppGap.sm),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('저장')),
      ]),
    ]);
  }
}
