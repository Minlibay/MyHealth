import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Какие источники выгружаются на сервер при синхронизации.
class SyncSettings {
  const SyncSettings({
    this.healthStore = true,
    this.ring = true,
    this.googleHealth = true,
  });

  /// Хранилище платформы: Apple Health (iOS) / Health Connect (Android).
  final bool healthStore;

  /// История с кольца/браслета.
  final bool ring;

  /// Подтягивать данные из Google Health (Fitbit) через сервер.
  final bool googleHealth;

  SyncSettings copyWith({bool? healthStore, bool? ring, bool? googleHealth}) =>
      SyncSettings(
        healthStore: healthStore ?? this.healthStore,
        ring: ring ?? this.ring,
        googleHealth: googleHealth ?? this.googleHealth,
      );
}

/// Ключи в SharedPreferences — читаются и фоновой задачей (другой isolate).
const syncHealthStoreKey = 'sync_health_store_v1';
const syncRingKey = 'sync_ring_v1';
const syncGoogleHealthKey = 'sync_google_health_v1';

class SyncSettingsController extends Notifier<SyncSettings> {
  @override
  SyncSettings build() {
    _load();
    return const SyncSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SyncSettings(
      healthStore: prefs.getBool(syncHealthStoreKey) ?? true,
      ring: prefs.getBool(syncRingKey) ?? true,
      googleHealth: prefs.getBool(syncGoogleHealthKey) ?? true,
    );
  }

  Future<void> setHealthStore(bool value) async {
    state = state.copyWith(healthStore: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(syncHealthStoreKey, value);
  }

  Future<void> setRing(bool value) async {
    state = state.copyWith(ring: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(syncRingKey, value);
  }

  Future<void> setGoogleHealth(bool value) async {
    state = state.copyWith(googleHealth: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(syncGoogleHealthKey, value);
  }
}

final syncSettingsProvider =
    NotifierProvider<SyncSettingsController, SyncSettings>(
        SyncSettingsController.new);
