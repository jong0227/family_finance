import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/components.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets.dart';

/// 더보기 — 계정, 가족 코드, 로그아웃. (계획 편집·알림 읽기·설정은 다음 단계)
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value;
    final code = ref.watch(inviteCodeProvider).value;
    final t = Theme.of(context).textTheme;
    return ListView(children: [
      const PageHeader('더보기'),
      const SectionTitle('가족'),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('가족 코드', style: t.labelMedium),
          const SizedBox(height: 2),
          Row(children: [
            Text(code ?? '…', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 3)),
            const Spacer(),
            if (code != null)
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('복사했어요')));
                },
                child: const Text('복사'),
              ),
          ]),
          Text('배우자는 이 앱과 Ninedogs 모두 구글로 로그인한 뒤 이 코드를 넣으면 같은 화면을 봐요', style: t.labelSmall),
        ]),
      ),
      const SectionTitle('계정'),
      Panel(
        child: Row(children: [
          Expanded(child: Text(user?.email ?? '', style: t.bodyMedium)),
          TextButton(
            onPressed: () async {
              await ref.read(householdIdProvider.notifier).set(null);
              await ref.read(authServiceProvider).signOut();
            },
            child: const Text('로그아웃'),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(AppGap.page),
        child: Text('계획 편집 · 뱅크샐러드 가져오기 · 알림 읽기는 다음 단계에서 붙어요', style: t.labelSmall),
      ),
    ]);
  }
}
