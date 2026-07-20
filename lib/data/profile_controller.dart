import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/profile_api.dart';
import 'auth/auth_controller.dart';
import 'ring/ring_providers.dart';
import 'user_profile.dart';

// cloudModeProvider живёт в providers.dart.
import '../providers.dart' show cloudModeProvider, insightsProvider;

final profileApiClientProvider =
    Provider<ProfileApi>((ref) => ProfileApi(ref.watch(apiClientProvider)));

/// Профиль: локальный кэш + сервер (в облачном режиме сервер — источник
/// истины). При сохранении отправляется в кольцо (точность калорий).
class ProfileController extends AsyncNotifier<UserProfile> {
  static const _key = 'user_profile_v1';

  @override
  Future<UserProfile> build() async {
    final prefs = await SharedPreferences.getInstance();
    var profile = _decode(prefs.getString(_key)) ?? const UserProfile();

    if (ref.watch(cloudModeProvider)) {
      try {
        profile = await ref.read(profileApiClientProvider).fetch();
        await prefs.setString(_key, jsonEncode(profile.toJson()));
      } catch (_) {
        // Офлайн — работаем с локальной копией.
      }
    }
    return profile;
  }

  Future<void> save(UserProfile profile) async {
    state = AsyncData(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));

    if (ref.read(cloudModeProvider)) {
      await ref.read(profileApiClientProvider).save(profile);
      // Цели влияют на скоры — пересчитываем.
      ref.invalidate(insightsProvider);
    }
    await sendToRing(profile);
  }

  /// Записывает профиль в кольцо (если подключено и данные заполнены).
  Future<void> sendToRing(UserProfile profile) async {
    if (!profile.isCompleteForRing) return;
    try {
      await ref.read(ringServiceProvider).setProfile(
            gender: profile.gender == 'male' ? 1 : 0,
            age: profile.age!,
            height: profile.heightCm!.round(),
            weight: profile.weightKg!.round(),
          );
    } catch (_) {
      // Кольцо не подключено — профиль уйдёт при следующем подключении.
    }
  }

  static UserProfile? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, UserProfile>(
        ProfileController.new);
