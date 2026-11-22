import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ninedogs_core/ninedogs_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_service.dart';
import '../data/finance_store.dart';
import '../data/shared/shared_household_store.dart';
import '../domain/diagnosis.dart';
import '../domain/finance_models.dart';

/// main() 에서 미리 열어 덮어쓴다.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final sharedStoreProvider = Provider<SharedHouseholdStore>((ref) => SharedHouseholdStore());

final userProvider = StreamProvider<User?>((ref) => ref.watch(authServiceProvider).changes);

/// 연결된 가구 id (기기에 기억). 없으면 초대 코드 입력 화면.
class HouseholdIdNotifier extends Notifier<String?> {
  static const _key = 'household_id_v1';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(_key);

  Future<void> set(String? id) async {
    final prefs = ref.read(sharedPreferencesProvider);
    id == null ? await prefs.remove(_key) : await prefs.setString(_key, id);
    state = id;
  }
}

final householdIdProvider = NotifierProvider<HouseholdIdNotifier, String?>(HouseholdIdNotifier.new);

final subscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final id = ref.watch(householdIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(sharedStoreProvider).watchSubscriptions(id);
});

final peopleProvider = StreamProvider<People>((ref) {
  final id = ref.watch(householdIdProvider);
  if (id == null) return Stream.value(People.defaults);
  return ref.watch(sharedStoreProvider).watchPeople(id);
});

/// 가구 초대 코드 (더보기에서 배우자에게 알려줄 때).
final inviteCodeProvider = FutureProvider<String?>((ref) {
  final id = ref.watch(householdIdProvider);
  if (id == null) return Future.value(null);
  return ref.watch(sharedStoreProvider).inviteCodeOf(id);
});

final financeStoreProvider = Provider<FinanceStore>((ref) => FinanceStore());

final monthsProvider = StreamProvider<List<MonthAgg>>((ref) {
  final id = ref.watch(householdIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(financeStoreProvider).watchMonths(id);
});

final planProvider = StreamProvider<Plan?>((ref) {
  final id = ref.watch(householdIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(financeStoreProvider).watchPlan(id);
});

/// 화면에서 고른 달. null 이면 데이터가 있는 가장 최근 달.
class SelectedMonthNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String month) => state = month;
}

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, String?>(SelectedMonthNotifier.new);

/// 실제로 보여줄 달 (고른 달, 없으면 최근 달).
final currentMonthProvider = Provider<String?>((ref) {
  final picked = ref.watch(selectedMonthProvider);
  if (picked != null) return picked;
  final months = ref.watch(monthsProvider).value ?? const [];
  return months.isEmpty ? null : months.last.month;
});

final livingTxProvider = StreamProvider.family<List<Tx>, String>((ref, group) {
  final id = ref.watch(householdIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(financeStoreProvider).watchLiving(id, group);
});

final transactionsProvider = StreamProvider.family<List<Tx>, String>((ref, month) {
  final id = ref.watch(householdIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(financeStoreProvider).watchTransactions(id, month);
});

/// 진단 결과 (계획 + 완전한 달 최근 6개월). 계획이 없으면 null.
final diagnosisProvider = Provider<DiagnosisResult?>((ref) {
  final plan = ref.watch(planProvider).value;
  final months = ref.watch(monthsProvider).value;
  if (plan == null || months == null) return null;
  return diagnose(plan: plan, months: months);
});

/// 아이별 지출에서 고른 항목(계획 분류 `c:…`, 생활비 구성 `p:…`) — 기기에 기억. 처음엔 비어 있다.
class KidCategoriesNotifier extends Notifier<Set<String>> {
  static const _key = 'kid_selection_v2';

  @override
  Set<String> build() => ref.watch(sharedPreferencesProvider).getStringList(_key)?.toSet() ?? const {};

  Future<void> set(Set<String> value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setStringList(_key, value.toList());
  }
}

final kidCategoriesProvider = NotifierProvider<KidCategoriesNotifier, Set<String>>(KidCategoriesNotifier.new);

/// 생활비 묶음 전체의 거래(구성별 월 지출용). 묶음마다 이미 구독 중인 [livingTxProvider] 를 모은다.
final allLivingTxProvider = Provider<List<Tx>>((ref) => [
      for (final g in livingGroups) ...(ref.watch(livingTxProvider(g)).value ?? const <Tx>[]),
    ]);
