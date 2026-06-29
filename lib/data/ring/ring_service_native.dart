import 'dart:async';

import 'package:flutter/services.dart';

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
    }
  }

  @override
  Stream<List<RingDevice>> get scanResults => _scan.stream;

  @override
  Stream<RingConnState> get connectionState => _state.stream;

  @override
  Stream<RingLiveData> get liveData => _data.stream;

  @override
  Future<void> startScan() => _methods.invokeMethod('startScan');

  @override
  Future<void> stopScan() => _methods.invokeMethod('stopScan');

  @override
  Future<void> connect(String deviceId) =>
      _methods.invokeMethod('connect', {'id': deviceId});

  @override
  Future<void> disconnect() => _methods.invokeMethod('disconnect');

  @override
  Future<void> measure() => _methods.invokeMethod('measure');

  @override
  void dispose() {
    _eventSub?.cancel();
    _scan.close();
    _state.close();
    _data.close();
  }
}
