import 'dart:async';
import 'dart:math';

import '../../core/health_metric.dart';
import '../../core/metric_source.dart';
import '../metric_sample.dart';
import '../sleep_session.dart';
import 'ring_history.dart';
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
  Future<void> connect(String deviceId, {bool auto = false}) async {
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
  Future<RingHistory> fetchHistory() async {
    await Future.delayed(const Duration(seconds: 2));
    final now = DateTime.now();
    final history = RingHistory();

    for (var day = 6; day >= 0; day--) {
      final d = DateTime(now.year, now.month, now.day - day);
      // Точки пульса/SpO2/температуры/HRV в течение дня.
      for (var h = 0; h < 24; h += 2) {
        final t = d.add(Duration(hours: h));
        if (t.isAfter(now)) break;
        history.samples.putIfAbsent(HealthMetric.heartRate, () => []).add(
            MetricSample(
                time: t,
                value: (58 + _rnd.nextInt(30)).toDouble(),
                source: MetricSource.ring));
        history.samples.putIfAbsent(HealthMetric.bloodOxygen, () => []).add(
            MetricSample(
                time: t,
                value: (95 + _rnd.nextInt(5)).toDouble(),
                source: MetricSource.ring));
        history.samples.putIfAbsent(HealthMetric.hrv, () => []).add(
            MetricSample(
                time: t,
                value: (35 + _rnd.nextInt(45)).toDouble(),
                source: MetricSource.ring));
      }
      // Суточная активность.
      history.samples.putIfAbsent(HealthMetric.steps, () => []).add(
          MetricSample(
              time: d,
              value: (5000 + _rnd.nextInt(6000)).toDouble(),
              source: MetricSource.ring));
      history.samples.putIfAbsent(HealthMetric.activeEnergy, () => []).add(
          MetricSample(
              time: d,
              value: (300 + _rnd.nextInt(350)).toDouble(),
              source: MetricSource.ring));

      // Ночь с фазами: отбой ~23:00, подъём ~7:00.
      final sleepStart =
          d.subtract(Duration(hours: 1, minutes: _rnd.nextInt(40)));
      var cursor = sleepStart;
      final stages = <SleepStage>[];
      final cycle = [
        SleepStageType.light,
        SleepStageType.deep,
        SleepStageType.light,
        SleepStageType.rem,
      ];
      for (var i = 0; i < 10; i++) {
        final stage = i == 5 && _rnd.nextBool()
            ? SleepStageType.awake
            : cycle[i % cycle.length];
        final minutes = stage == SleepStageType.awake
            ? 5 + _rnd.nextInt(10)
            : 35 + _rnd.nextInt(40);
        final end = cursor.add(Duration(minutes: minutes));
        stages.add(SleepStage(stage: stage, start: cursor, end: end));
        cursor = end;
      }
      history.sleepSessions.add(SleepSessionModel(
        start: sleepStart,
        end: cursor,
        stages: stages,
        source: MetricSource.ring,
      ));
    }
    history.sleepSessions.sort((a, b) => b.start.compareTo(a.start));
    return history;
  }

  @override
  Future<void> enableAutoMonitoring({int intervalMinutes = 15}) async {}

  @override
  Future<void> setProfile({
    required int gender,
    required int age,
    required int height,
    required int weight,
  }) async {}

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
