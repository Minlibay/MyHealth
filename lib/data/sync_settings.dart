import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Какие источники выгружаются на сервер при синхронизации.
class SyncSettings {
  const SyncSettings({this.healthStore = true, this.ring = true});

  /// Хранилище платформы: Apple Health (iOS) / Health Connect (Android).
  final bool healthStore;

  /// История с кольца/браслета.
  final bool ring;

  SyncSettings copyWith({bool? healthStore, bool? ring}) => SyncSettings(
        healthStore: healthStore ?? this.healthStore,
        ring: ring ?? this.ring,
      );
}

/// Ключи в SharedPreferences — читаются и фоновой задачей (другой isolate).
const syncHealthStoreKey = 'sync_health_store_v1';
const syncRingKey = 'sync_ring_v1';

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
}

final syncSettingsProvider =
    NotifierProvider<SyncSettingsController, SyncSettings>(
        SyncSettingsController.new);
