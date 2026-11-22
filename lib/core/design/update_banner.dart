import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/update.dart';
import 'tokens.dart';

/// 새 버전이 있으면 화면 맨 위에 한 줄로 뜬다. 누르면 내려받아 설치 화면이 열린다.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(availableUpdateProvider).value;
    final progress = ref.watch(updateProgressProvider);
    if (release == null || release.apkUrl == null) return const SizedBox.shrink();
    final p = context.palette;
    return Material(
      color: p.infoBg,
      child: InkWell(
        onTap: progress == null ? () => ref.read(updateProgressProvider.notifier).install(context, release) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppGap.page, vertical: AppGap.sm),
          child: Row(children: [
            Icon(Icons.system_update_alt, size: 18, color: p.info),
            const SizedBox(width: AppGap.sm),
            Expanded(
              child: Text(
                progress == null ? '새 버전 ${release.version} — 눌러서 업데이트' : '내려받는 중 ${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.info),
              ),
            ),
            if (progress != null)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, value: progress)),
          ]),
        ),
      ),
    );
  }
}
