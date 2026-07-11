import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ring_models.dart';
import 'ring_providers.dart';

/// Сохранённое кольцо пользователя. При старте приложения автоматически
/// поднимает соединение (auto=true — стек BLE подключится сам, когда
/// кольцо окажется рядом), чтобы не приходилось подключать заново.
class RingConnectionController extends AsyncNotifier<RingDevice?> {
  static const _idKey = 'ring_device_id_v1';
  static const _nameKey = 'ring_device_name_v1';

  @override
  Future<RingDevice?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_idKey);
    if (id == null) return null;
    final device = RingDevice(
      id: id,
      name: prefs.getString(_nameKey) ?? 'Кольцо',
    );
    // Ошибки автоподключения не всплывают: кольцо может быть вне зоны.
    ref
        .read(ringServiceProvider)
        .connect(id, auto: true)
        .catchError((_) {});
    return device;
  }

  /// Подключение из списка сканирования + запоминание устройства.
  Future<void> connectAndRemember(RingDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKey, device.id);
    await prefs.setString(_nameKey, device.name);
    state = AsyncData(device);
    await ref.read(ringServiceProvider).connect(device.id);
  }

  /// Отключить и забыть кольцо (перестаём автоподключаться).
  Future<void> forget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idKey);
    await prefs.remove(_nameKey);
    state = const AsyncData(null);
    await ref.read(ringServiceProvider).disconnect();
  }
}

final ringConnectionControllerProvider =
    AsyncNotifierProvider<RingConnectionController, RingDevice?>(
        RingConnectionController.new);
