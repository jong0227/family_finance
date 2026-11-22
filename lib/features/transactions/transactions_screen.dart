import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';

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
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
        child: Wrap(spacing: AppGap.sm, children: [
          ChoiceChip(label: const Text('소비만'), selected: _onlySpending, onSelected: (_) => setState(() => _onlySpending = true)),
          ChoiceChip(label: const Text('전체'), selected: !_onlySpending, onSelected: (_) => setState(() => _onlySpending = false)),
        ]),
      ),
      Expanded(
        child: txs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (all) {
            final list = _onlySpending ? all.where((t) => t.kind == '소비').toList() : all;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppGap.page, vertical: AppGap.xs),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final t = list[i];
                final income = t.amount > 0;
                return AmountRow(
                  title: t.merchant,
                  sub: '${t.date.substring(5).replaceAll('-', '/')} · ${t.kind == '소비' ? t.category : t.kind} · ${t.payment}'
                      '${t.oneOff ? ' · 일회성' : ''}',
                  amount: '${income ? '+' : ''}${won(t.amount.abs())}',
                  amountColor: income ? p.under : null,
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}
