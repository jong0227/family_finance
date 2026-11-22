import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/update_service.dart';

export '../data/update_service.dart' show AppRelease;

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

final appVersionProvider = FutureProvider<String>((ref) async => (await PackageInfo.fromPlatform()).version);

/// 새 버전(있으면). 앱을 켤 때 한 번 확인하고, 더보기에서 다시 확인할 수 있다.
final availableUpdateProvider = FutureProvider<AppRelease?>((ref) async {
  final current = await ref.watch(appVersionProvider.future);
  return ref.watch(updateServiceProvider).newerThan(current);
});

/// 내려받기 진행률 (null = 받는 중 아님).
class UpdateProgressNotifier extends Notifier<double?> {
  @override
  double? build() => null;

  Future<void> install(BuildContext context, AppRelease release) async {
    final url = release.apkUrl;
    if (url == null || state != null) return;
    final messenger = ScaffoldMessenger.of(context);
    state = 0;
    try {
      await ref.read(updateServiceProvider).downloadAndInstall(url, onProgress: (p) => state = p);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('업데이트를 받지 못했어요: $e')));
    } finally {
      state = null;
    }
  }
}

final updateProgressProvider = NotifierProvider<UpdateProgressNotifier, double?>(UpdateProgressNotifier.new);
