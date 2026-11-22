import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import 'tx_note_sheet.dart';

/// 거래 — 고른 달의 거래 목록. 기본은 소비만.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  bool _onlySpending = true;

  @override
  Widget build(BuildContext context) {
    final months = ref.watch(monthsProvider).value ?? const [];
    final month = ref.watch(currentMonthProvider);
    final p = context.palette;
    if (month == null) return const Center(child: Text('아직 데이터가 없어요'));
    final txs = ref.watch(transactionsProvider(month));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MonthSwitcher(
        month: month,
        months: [for (final m in months) m.month],
        onChanged: ref.read(selectedMonthProvider.notifier).set,
      ),
      ChipBar(children: [
        ChoiceChip(label: const Text('소비만'), selected: _onlySpending, onSelected: (_) => setState(() => _onlySpending = true)),
        ChoiceChip(label: const Text('전체'), selected: !_onlySpending, onSelected: (_) => setState(() => _onlySpending = false)),
      ]),
      Expanded(
        child: txs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (all) {
            final list = _onlySpending ? all.where((t) => t.kind == '소비').toList() : all;
            const r = Radius.circular(AppRadius.lg);
            // 목록이 길어 카드 하나로 감싸지 않고, 행마다 같은 흰 바탕을 이어 붙여 한 장처럼 보이게(지연 생성 유지).
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppGap.page, AppGap.xs, AppGap.page, AppGap.xl),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final t = list[i];
                final first = i == 0, last = i == list.length - 1;
                return Container(
                  padding: EdgeInsets.fromLTRB(AppGap.sm, first ? AppGap.xs : 0, AppGap.sm, last ? AppGap.xs : 0),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.vertical(top: first ? r : Radius.zero, bottom: last ? r : Radius.zero),
                  ),
                  child: AmountRow(
                    onTap: () => showTxNoteSheet(context, t),
                    title: t.merchant,
                    sub: '${t.date.substring(5).replaceAll('-', '/')} · ${t.kind == '소비' ? t.category : t.kind} · ${t.payment}'
                        '${t.oneOff ? ' · 일회성' : ''}'
                        '${t.note.isEmpty ? '' : ' · ${t.note}'}'
                        '${t.userTags.isEmpty ? '' : ' · ${t.userTags.map((x) => '#$x').join(' ')}'}',
                    amount: txWon(t.amount),
                    amountColor: t.amount > 0 ? p.under : null,
                    divider: !last,
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}
