import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';
import '../../core/format/won.dart';
import '../../domain/cash_check.dart';
import '../../domain/timeline.dart' show addMonths;

String _md(DateTime d) => '${d.month}/${d.day}';

/// 결제일 현금 점검(S1) — 통장별 빠질 돈 vs 직접 입력한 잔액. 잔액은 앱이 알 수 없어 손으로 넣는다.
class CashCheckScreen extends ConsumerStatefulWidget {
  const CashCheckScreen({super.key});

  @override
  ConsumerState<CashCheckScreen> createState() => _CashCheckScreenState();
}

class _CashCheckScreenState extends ConsumerState<CashCheckScreen> {
  late String _month = () {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }();

  Future<void> _editBalance(AccountCash a) async {
    final c = TextEditingController(text: a.balance?.toString() ?? '');
    final actions = ref.read(financeNoteActionsProvider);
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${a.name} 잔액', style: AppText.title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppText.body,
          decoration: const InputDecoration(hintText: '지금 잔액(원) · 비우면 입력 지움'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('저장')),
        ],
      ),
    );
    if (v == null || a.accountId == null) return;
    await actions.setBalance(_month, a.accountId!, v.isEmpty ? null : int.tryParse(v));
  }

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(cashCheckProvider(_month));
    final p = context.palette;
    final months = [addMonths(_month, -1), _month, addMonths(_month, 1)];
    return Scaffold(
      appBar: AppBar(title: const Text('결제일 현금 점검')),
      body: res == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: AppGap.xl), children: [
              MonthSwitcher(month: _month, months: months, onChanged: (m) => setState(() => _month = m)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppGap.page),
                child: Row(children: [
                  KpiTile(
                    label: '부족 합계',
                    value: man(res.shortfallTotal),
                    sub: res.missingBalanceCount > 0 ? '잔액 미입력 ${res.missingBalanceCount}곳 제외' : '날짜 있는 출금 기준',
                    valueColor: res.shortfallTotal > 0 ? p.over : null,
                  ),
                  const SizedBox(width: AppGap.sm),
                  KpiTile(label: '옮길 수 있는 여유', value: man(res.spareTotal), sub: '제외 표시한 통장 빼고'),
                ]),
              ),
              if (res.accounts.isEmpty)
                const Padding(padding: EdgeInsets.all(AppGap.page), child: Text('출금 통장이 정해진 계획 항목이 아직 없어요')),
              for (final a in res.accounts) _account(a, p),
              if (res.unassigned.isNotEmpty)
                SectionCard(
                  title: '출금 통장 미지정',
                  trailing: '${res.unassigned.length}개 · 점검에서 빠짐',
                  child: Text(
                    res.unassigned.take(8).map((i) => i.name).join(' · ') + (res.unassigned.length > 8 ? ' …' : ''),
                    style: AppText.caption.copyWith(color: p.textSub),
                  ),
                ),
              const FootNote('잔액은 직접 입력한 값만 써요 · 카드 대금은 계획 항목 합계로 추정 · 결제일이 주말이면 다음 월요일로 계산(공휴일은 반영 안 함) · 마이너스 한도는 현금이 아니에요'),
            ]),
    );
  }

  Widget _account(AccountCash a, Palette p) {
    final short = a.shortfall;
    final withUndated = a.shortfallWithUndated;
    final String status;
    Color? color;
    if (a.balance == null) {
      status = '잔액 미입력';
    } else if ((short ?? 0) > 0) {
      status = '${man(short!)} 부족${a.firstShortDate == null ? '' : ' · ${_md(a.firstShortDate!)}부터'}';
      color = p.over;
    } else if ((withUndated ?? 0) > 0) {
      status = '날짜 미정 포함 시 ${man(withUndated!)} 부족';
      color = p.over;
    } else {
      status = '여유 ${man(a.balance! - a.total)}';
      color = p.under;
    }
    return SectionCard(
      title: a.name,
      trailing: status,
      list: true,
      child: Column(children: [
        AmountRow(
          onTap: a.accountId == null ? null : () => _editBalance(a),
          title: '현재 잔액',
          sub: a.excluded ? '쓸 수 없는 돈으로 표시됨' : '눌러서 입력',
          amount: a.balance == null ? '—' : won(a.balance!),
          amountColor: color,
        ),
        for (final o in a.outflows)
          AmountRow(
            title: o.name,
            sub: o.date == null ? '날짜 미정${(o.payDayText ?? '').isEmpty ? '' : ' · ${o.payDayText}'}' : _md(o.date!),
            amount: '−${won(o.amount)}',
          ),
        AmountRow(title: '빠질 돈 합계', sub: a.undatedTotal > 0 ? '날짜 미정 ${man(a.undatedTotal)} 포함' : null, amount: won(a.total), divider: false),
        if (a.accountId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref.read(financeNoteActionsProvider).setExcluded(_month, a.accountId!, !a.excluded),
              child: Text(a.excluded ? '여유로 다시 치기' : '쓸 수 없는 돈으로 표시'),
            ),
          ),
      ]),
    );
  }
}
