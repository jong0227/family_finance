import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/design/tokens.dart';

/// 처음 실행: ① 구글 로그인 → ② Ninedogs 초대 코드로 우리 가족에 연결.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.signedIn});
  final bool signedIn;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object e) {
    final s = e.toString();
    if (s.contains('InviteCodeNotFound')) return '그 코드를 찾지 못했어요. Ninedogs 설정 > 가족 연결의 코드를 확인해 주세요';
    if (s.contains('canceled') || s.contains('Canceled')) return '로그인을 취소했어요';
    return '문제가 생겼어요: $s';
  }

  Future<void> _signIn() => _run(() async {
        await ref.read(authServiceProvider).signIn();
      });

  Future<void> _join() => _run(() async {
        final user = ref.read(authServiceProvider).user;
        if (user == null) throw StateError('로그인이 필요해요');
        final id = await ref.read(sharedStoreProvider).joinByInviteCode(_code.text, user.uid);
        await ref.read(householdIdProvider.notifier).set(id);
      });

  /// 초대 코드가 없으면 새 가족 묶음을 만든다. 코드는 더보기에서 볼 수 있다.
  Future<void> _skip() => _run(() async {
        final user = ref.read(authServiceProvider).user;
        if (user == null) throw StateError('로그인이 필요해요');
        final id = await ref.read(sharedStoreProvider).createHousehold(user.uid);
        await ref.read(householdIdProvider.notifier).set(id);
      });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppGap.xxl, vertical: AppGap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('우리집 가계', style: AppText.titleLg),
              const SizedBox(height: AppGap.xs),
              Text('부부가 같은 화면으로 지출과 정기결제를 봐요', style: AppText.caption.copyWith(color: p.textSub)),
              const SizedBox(height: AppGap.xl),
              if (!widget.signedIn) ...[
                Text('1. 구글 계정으로 로그인', style: AppText.title),
                const SizedBox(height: AppGap.sm),
                FilledButton(onPressed: _busy ? null : _signIn, child: const Text('구글로 로그인')),
              ] else ...[
                Text('2. 우리 가족에 연결', style: AppText.title),
                const SizedBox(height: AppGap.xs),
                Text('Ninedogs > 설정 > 가족 연결에 있는 6자리 코드를 넣어 주세요', style: AppText.caption.copyWith(color: p.textSub)),
                const SizedBox(height: AppGap.sm),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: '초대 코드'),
                ),
                const SizedBox(height: AppGap.sm),
                FilledButton(onPressed: _busy ? null : _join, child: const Text('연결')),
                const SizedBox(height: AppGap.xs),
                TextButton(
                  onPressed: _busy ? null : _skip,
                  child: const Text('코드 없이 새로 시작 (건너뛰기)'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppGap.md),
                Text(_error!, style: AppText.caption.copyWith(color: p.over)),
              ],
              if (_busy) const Padding(padding: EdgeInsets.only(top: AppGap.lg), child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      ),
    );
  }
}
