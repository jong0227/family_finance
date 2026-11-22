import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../app/update.dart';
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
    final p = context.palette;
    return ListView(children: [
      const PageHeader('더보기'),
      SectionCard(
        title: '가족',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('가족 코드', style: AppText.caption.copyWith(color: p.textMuted)),
            const SizedBox(width: AppGap.sm),
            Text(code ?? '…', style: AppText.code.tnum),
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
          Text('배우자는 이 앱과 Ninedogs 모두 구글로 로그인한 뒤 이 코드를 넣으면 같은 화면을 봐요',
              style: AppText.caption.copyWith(color: p.textSub)),
        ]),
      ),
      SectionCard(title: '앱', child: _UpdateTile()),
      SectionCard(
        title: '계정',
        child: Row(children: [
          Expanded(child: Text(user?.email ?? '', style: AppText.body, overflow: TextOverflow.ellipsis)),
          TextButton(
            onPressed: () async {
              await ref.read(householdIdProvider.notifier).set(null);
              await ref.read(authServiceProvider).signOut();
            },
            child: const Text('로그아웃'),
          ),
        ]),
      ),
      const FootNote('계획 편집 · 뱅크샐러드 가져오기 · 알림 읽기는 다음 단계에서 붙어요'),
    ]);
  }
}

class _UpdateTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value ?? '';
    final update = ref.watch(availableUpdateProvider);
    final progress = ref.watch(updateProgressProvider);
    final p = context.palette;
    final release = update.value;
    final status = update.isLoading
        ? '확인 중…'
        : progress != null
            ? '내려받는 중 ${(progress * 100).toStringAsFixed(0)}%'
            : release != null
                ? '새 버전 ${release.version} 있어요'
                : '최신 버전이에요';
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('버전 $version', style: AppText.body.tnum),
          Text(status, style: AppText.caption.copyWith(color: release != null ? p.info : p.textSub).tnum),
        ]),
      ),
      if (release != null && progress == null)
        FilledButton(
          onPressed: () => ref.read(updateProgressProvider.notifier).install(context, release),
          child: const Text('업데이트'),
        )
      else
        TextButton(
          onPressed: progress == null ? () => ref.invalidate(availableUpdateProvider) : null,
          child: const Text('다시 확인'),
        ),
    ]);
  }
}
