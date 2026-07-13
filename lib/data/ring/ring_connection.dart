import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ring_models.dart';
import 'ring_providers.dart';

/// Сохранённые носимые устройства пользователя (кольца/браслеты) и
/// активное из них. Подключение одновременно одно — BLE-мост держит одну
/// сессию; переключение между устройствами без повторного сканирования.
class RingDevicesState {
  const RingDevicesState({this.devices = const [], this.activeId});

  final List<RingDevice> devices;
  final String? activeId;

  RingDevice? get active {
    for (final d in devices) {
      if (d.id == activeId) return d;
    }
    return null;
  }
}

class RingDevicesController extends AsyncNotifier<RingDevicesState> {
  static const _devicesKey = 'ring_devices_v1';
  static const _activeKey = 'ring_active_v1';
  // Ключи одноустройственной версии — для миграции.
  static const _legacyIdKey = 'ring_device_id_v1';
  static const _legacyNameKey = 'ring_device_name_v1';

  @override
  Future<RingDevicesState> build() async {
    final prefs = await SharedPreferences.getInstance();

    var devices = _decode(prefs.getString(_devicesKey));
    var activeId = prefs.getString(_activeKey);

    // Миграция со старого формата (одно сохранённое кольцо).
    final legacyId = prefs.getString(_legacyIdKey);
    if (devices.isEmpty && legacyId != null) {
      devices = [
        RingDevice(
            id: legacyId,
            name: prefs.getString(_legacyNameKey) ?? 'Кольцо'),
      ];
      activeId = legacyId;
      await _persist(prefs, devices, activeId);
      await prefs.remove(_legacyIdKey);
      await prefs.remove(_legacyNameKey);
    }

    final state = RingDevicesState(devices: devices, activeId: activeId);
    // Автоподключение к активному устройству; ошибки не всплывают —
    // устройство может быть вне зоны.
    final active = state.active;
    if (active != null) {
      ref
          .read(ringServiceProvider)
          .connect(active.id, auto: true)
          .catchError((_) {});
    }
    return state;
  }

  /// Подключиться к устройству и сделать его активным (добавив в список).
  Future<void> connectAndRemember(RingDevice device) async {
    final current = state.value ?? const RingDevicesState();
    final devices = [
      for (final d in current.devices)
        if (d.id != device.id) d,
      RingDevice(id: device.id, name: device.name),
    ];
    await _save(devices, device.id);
    final service = ref.read(ringServiceProvider);
    // Переключение: старая сессия закрывается, подключаемся к выбранному.
    if (current.activeId != null && current.activeId != device.id) {
      await service.disconnect();
    }
    await service.connect(device.id);
  }

  /// Убрать устройство из списка; если оно активно — отключиться.
  Future<void> forget(String deviceId) async {
    final current = state.value ?? const RingDevicesState();
    final devices =
        current.devices.where((d) => d.id != deviceId).toList();
    final wasActive = current.activeId == deviceId;
    await _save(devices, wasActive ? null : current.activeId);
    if (wasActive) {
      await ref.read(ringServiceProvider).disconnect();
    }
  }

  Future<void> _save(List<RingDevice> devices, String? activeId) async {
    final prefs = await SharedPreferences.getInstance();
    await _persist(prefs, devices, activeId);
    state = AsyncData(RingDevicesState(devices: devices, activeId: activeId));
  }

  static Future<void> _persist(
      SharedPreferences prefs, List<RingDevice> devices, String? activeId) async {
    await prefs.setString(
      _devicesKey,
      jsonEncode([
        for (final d in devices) {'id': d.id, 'name': d.name}
      ]),
    );
    if (activeId == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, activeId);
    }
  }

  static List<RingDevice> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          RingDevice(
              id: (e as Map)['id'] as String,
              name: (e['name'] as String?) ?? 'Устройство'),
      ];
    } catch (_) {
      return const [];
    }
  }
}

final ringDevicesProvider =
    AsyncNotifierProvider<RingDevicesController, RingDevicesState>(
        RingDevicesController.new);
