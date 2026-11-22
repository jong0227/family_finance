import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/theme.dart';
import '../features/home/home_screen.dart';
import '../features/more/more_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/recurring/recurring_screen.dart';
import '../features/transactions/transactions_screen.dart';
import '../features/trends/trends_screen.dart';
import 'session.dart';

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '우리집 가계',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Gate(),
      );
}

/// 로그인 안 됨 / 가구 연결 안 됨 → 온보딩, 둘 다 되면 탭 틀.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final householdId = ref.watch(householdIdProvider);
    return user.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('로그인 상태를 읽지 못했어요\n$e'))),
      data: (u) => (u == null || householdId == null) ? OnboardingScreen(signedIn: u != null) : const AppShell(),
    );
  }
}

/// 하단 탭 5개 (SCREENS.md 1.1): 이번 달 · 추이 · 거래 · 정기 · 더보기.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [HomeScreen(), TrendsScreen(), TransactionsScreen(), RecurringScreen(), MoreScreen()];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: IndexedStack(index: _index, children: _pages)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: '이번 달'),
            NavigationDestination(icon: Icon(Icons.show_chart), label: '추이'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: '거래'),
            NavigationDestination(icon: Icon(Icons.autorenew), label: '정기'),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: '더보기'),
          ],
        ),
      );
}
