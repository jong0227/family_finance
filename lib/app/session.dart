import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ninedogs_core/ninedogs_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_service.dart';
import '../data/shared/shared_household_store.dart';

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
