import 'dart:async';

import 'package:flutter/services.dart';

import 'ring_history.dart';
import 'ring_models.dart';
import 'ring_service.dart';

RingService createRingService() => RingServiceNative();

/// Нативная реализация: BLE через платформенный канал к Jstyle SDK
/// (Android: com.jstyle.blesdkx3, iOS: libBleSDK.a).
class RingServiceNative implements RingService {
  static const _methods = MethodChannel('jcring_x3/methods');
  static const _events = EventChannel('jcring_x3/events');

  final _scan = StreamController<List<RingDevice>>.broadcast();
  final _state = StreamController<RingConnState>.broadcast();
  final _data = StreamController<RingLiveData>.broadcast();

  StreamSubscription? _eventSub;
  RingLiveData _last = RingLiveData(time: DateTime.now());

  RingServiceNative() {
    _eventSub = _events.receiveBroadcastStream().listen(_onEvent);
  }

  // Активная выкачка истории: builder копит записи до события historyDone.
  RingHistoryBuilder? _historyBuilder;
  Completer<RingHistory>? _historyCompleter;

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    switch (event['type']) {
      case 'scan':
        final list = (event['devices'] as List? ?? [])
            .map((e) => RingDevice.fromMap(e as Map))
            .toList();
        _scan.add(list);
      case 'state':
        _state.add(RingConnState.values.firstWhere(
          (s) => s.name == event['state'],
          orElse: () => RingConnState.disconnected,
        ));
      case 'data':
        _last = _last.merge(event);
        _data.add(_last);
      case 'history':
        final builder = _historyBuilder;
        if (builder == null) return;
        final records = [
          for (final raw in (event['records'] as List? ?? []))
            (raw as Map).map((k, v) => MapEntry(k.toString(), v?.toString())),
        ];
        builder.addRecords(event['kind'] as String? ?? '', records);
      case 'historyDone':
        final completer = _historyCompleter;
        final builder = _historyBuilder;
        _historyCompleter = null;
        _historyBuilder = null;
        if (completer != null && !completer.isCompleted) {
          if (event['ok'] == false) {
            completer.completeError(
                StateError(event['error'] as String? ?? 'sync_failed'));
          } else {
            completer.complete(builder?.build() ?? RingHistory());
          }
        }
    }
  }

  @override
  Stream<List<RingDevice>> get scanResults => _scan.stream;

  @override
  Stream<RingConnState> get connectionState => _state.stream;

  @override
  Stream<RingLiveData> get liveData => _data.stream;

  @override
  Future<void> startScan({bool showAll = false}) =>
      _methods.invokeMethod('startScan', {'showAll': showAll});

  @override
  Future<void> stopScan() => _methods.invokeMethod('stopScan');

  @override
  Future<void> connect(String deviceId, {bool auto = false}) =>
      _methods.invokeMethod('connect', {'id': deviceId, 'auto': auto});

  @override
  Future<void> disconnect() => _methods.invokeMethod('disconnect');

  @override
  Future<void> measure() => _methods.invokeMethod('measure');

  @override
  Future<RingHistory> fetchHistory() async {
    // Повторный вызов во время выкачки возвращает тот же результат.
    final active = _historyCompleter;
    if (active != null) return active.future;

    final completer = Completer<RingHistory>();
    _historyCompleter = completer;
    _historyBuilder = RingHistoryBuilder();
    await _methods.invokeMethod('syncHistory');
    // Страховка: история семи типов с пагинацией не должна идти дольше 3 минут.
    return completer.future.timeout(const Duration(minutes: 3), onTimeout: () {
      final builder = _historyBuilder;
      _historyCompleter = null;
      _historyBuilder = null;
      return builder?.build() ?? RingHistory();
    });
  }

  @override
  Future<void> enableAutoMonitoring({int intervalMinutes = 15}) =>
      _methods.invokeMethod(
          'enableAutoMonitoring', {'intervalMinutes': intervalMinutes});

  @override
  Future<void> setProfile({
    required int gender,
    required int age,
    required int height,
    required int weight,
  }) =>
      _methods.invokeMethod('setProfile', {
        'gender': gender,
        'age': age,
        'height': height,
        'weight': weight,
      });

  @override
  void dispose() {
    _eventSub?.cancel();
    _scan.close();
    _state.close();
    _data.close();
  }
}
