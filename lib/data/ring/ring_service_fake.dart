import 'dart:async';
import 'dart:math';

import 'ring_models.dart';
import 'ring_service.dart';

RingService createRingService() => RingServiceFake();

/// Фейковое кольцо для web/разработки: имитирует скан, подключение и живые
/// показатели, чтобы UI можно было гонять без устройства.
class RingServiceFake implements RingService {
  final _scan = StreamController<List<RingDevice>>.broadcast();
  final _state = StreamController<RingConnState>.broadcast();
  final _data = StreamController<RingLiveData>.broadcast();
  final _rnd = Random();
  Timer? _scanTimer;
  Timer? _liveTimer;

  @override
  Stream<List<RingDevice>> get scanResults => _scan.stream;
  @override
  Stream<RingConnState> get connectionState => _state.stream;
  @override
  Stream<RingLiveData> get liveData => _data.stream;

  @override
  Future<void> startScan() async {
    _state.add(RingConnState.scanning);
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(milliseconds: 800), () {
      _scan.add(const [
        RingDevice(id: 'DEMO-X3-01', name: 'JCRing X3 (демо)', rssi: -52),
        RingDevice(id: 'DEMO-X3-02', name: 'JCRing X3 Med', rssi: -71),
      ]);
      _state.add(RingConnState.disconnected);
    });
  }

  @override
  Future<void> stopScan() async => _scanTimer?.cancel();

  @override
  Future<void> connect(String deviceId) async {
    _state.add(RingConnState.connecting);
    await Future.delayed(const Duration(milliseconds: 700));
    _state.add(RingConnState.connected);
    _emit();
    _liveTimer?.cancel();
    _liveTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _emit());
  }

  void _emit() {
    _data.add(RingLiveData(
      heartRate: 64 + _rnd.nextInt(20),
      spo2: 96 + _rnd.nextInt(4),
      temperature: 36.4 + _rnd.nextDouble() * 0.8,
      hrv: 40 + _rnd.nextInt(40),
      battery: 70 + _rnd.nextInt(30),
      steps: 5000 + _rnd.nextInt(4000),
      time: DateTime.now(),
    ));
  }

  @override
  Future<void> measure() async => _emit();

  @override
  Future<void> disconnect() async {
    _liveTimer?.cancel();
    _state.add(RingConnState.disconnected);
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _liveTimer?.cancel();
    _scan.close();
    _state.close();
    _data.close();
  }
}
