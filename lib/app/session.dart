import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ninedogs_core/ninedogs_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_service.dart';
import '../data/finance_store.dart';
import '../data/shared/shared_household_store.dart';
import '../domain/diagnosis.dart';
import '../domain/finance_models.dart';
import '../domain/plan_edit.dart';

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

final accountsProvider = StreamProvider<List<AccountRef>>((ref) {
  final id = ref.watch(householdIdProvider);
  if (id == null) return Stream.value(const []);
  return ref.watch(financeStoreProvider).watchAccounts(id);
});

/// 서버에서 본 가장 높은 계약 버전. 이 앱(kContractVersion)보다 높으면 구독 쓰기를 막는다.
final contractVersionProvider = StreamProvider<int>((ref) {
  final id = ref.watch(householdIdProvider);
  if (id == null) return Stream.value(kContractVersion);
  return ref.watch(sharedStoreProvider).watchContractVersion(id);
});

/// 구독 읽기 전용 여부(더 새로운 계약 버전이 서버에 있음).
final subscriptionsReadOnlyProvider =
    Provider<bool>((ref) => (ref.watch(contractVersionProvider).value ?? kContractVersion) > kContractVersion);

/// 계획 편집 동작 — 화면은 이것만 부른다(data 를 직접 import 하지 않음).
class PlanActions {
  PlanActions(this._ref);
  final Ref _ref;

  Future<void> _edit(PlanTransform t) {
    final hid = _ref.read(householdIdProvider);
    if (hid == null) throw const PlanEditError('가구가 연결돼 있지 않아요');
    return _ref.read(financeStoreProvider).editPlan(hid, t, by: _ref.read(userProvider).value?.uid);
  }

  Future<void> update(String itemId, PlanItemFields f) => _edit((d) => updatePlanItem(d, itemId, f));

  Future<void> add(String group, String category, String name, PlanItemFields f) {
    final id = newPlanItemId();
    return _edit((d) => addPlanItem(d, group: group, category: category, name: name, fields: f, newId: id));
  }

  Future<void> delete(String itemId) => _edit((d) => deletePlanItem(d, itemId));
}

final planActionsProvider = Provider<PlanActions>(PlanActions.new);

/// 구독 쓰기 동작. 계약 버전이 높으면 [ContractTooNewException].
class SubscriptionActions {
  SubscriptionActions(this._ref);
  final Ref _ref;

  String _hid() => _ref.read(householdIdProvider) ?? (throw StateError('가구가 연결돼 있지 않아요'));

  Future<void> save(Subscription s) => _ref.read(sharedStoreProvider).saveSubscription(_hid(), s);
  Future<void> delete(String id) => _ref.read(sharedStoreProvider).deleteSubscription(_hid(), id);
}

final subscriptionActionsProvider = Provider<SubscriptionActions>(SubscriptionActions.new);
