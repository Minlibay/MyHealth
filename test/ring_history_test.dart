import 'package:flutter_test/flutter_test.dart';
import 'package:myhealth/core/health_metric.dart';
import 'package:myhealth/data/ring/ring_history.dart';
import 'package:myhealth/data/sleep_session.dart';

void main() {
  group('RingHistoryBuilder', () {
    test('сон: коды фаз склеиваются в сегменты с учётом сетки', () {
      final b = RingHistoryBuilder();
      b.addRecords('sleep', [
        {
          'date': '2026.07.10 23:00:00',
          // 1=deep, 2=light, 3=rem, 4=awake; 5-минутная сетка
          'arraySleepQuality': '2 2 1 1 1 3 3 4 2',
          'sleepUnitLength': '5',
        }
      ]);
      final h = b.build();

      expect(h.sleepSessions, hasLength(1));
      final s = h.sleepSessions.first;
      expect(s.start, DateTime(2026, 7, 10, 23));
      expect(s.end, DateTime(2026, 7, 10, 23, 45)); // 9 * 5 мин
      expect(s.stages, hasLength(5)); // light,deep,rem,awake,light
      expect(s.stages.first.stage, SleepStageType.light);
      expect(s.stages.first.duration, const Duration(minutes: 10));
      expect(s.stages[1].stage, SleepStageType.deep);
      expect(s.stages[1].duration, const Duration(minutes: 15));
      expect(s.hoursOf(SleepStageType.rem), const Duration(minutes: 10));
      expect(s.hoursOf(SleepStageType.awake), const Duration(minutes: 5));
      expect(s.asleep, const Duration(minutes: 40));
    });

    test('активность: суточные итоги раскладываются по метрикам', () {
      final b = RingHistoryBuilder();
      b.addRecords('activity', [
        {'date': '2026.07.10', 'step': '8500', 'calories': '412.5', 'distance': '6.2'},
      ]);
      final h = b.build();

      expect(h.samples[HealthMetric.steps]!.single.value, 8500);
      expect(h.samples[HealthMetric.activeEnergy]!.single.value, 412.5);
      expect(h.samples[HealthMetric.distance]!.single.value, 6.2);
    });

    test('пульс: массив значений усредняется, мусор отфильтровывается', () {
      final b = RingHistoryBuilder();
      b.addRecords('dynamicHr', [
        {'date': '2026-07-10 08:00:00', 'arrayDynamicHR': '60 70 80 0 255'},
      ]);
      final h = b.build();

      final hr = h.samples[HealthMetric.heartRate]!;
      expect(hr, hasLength(1));
      expect(hr.single.value, 70); // (60+70+80)/3, 0 и 255 отброшены
    });

    test('iOS-ключи (singleHR, spo2) тоже распознаются', () {
      final b = RingHistoryBuilder();
      b.addRecords('staticHr', [
        {'date': '2026-07-10 09:00:00', 'singleHR': '64'},
      ]);
      b.addRecords('spo2', [
        {'date': '2026-07-10 09:00:00', 'spo2': '98'},
      ]);
      final h = b.build();

      expect(h.samples[HealthMetric.heartRate]!.single.value, 64);
      expect(h.samples[HealthMetric.bloodOxygen]!.single.value, 98);
      expect(h.totalRecords, 2);
    });

    test('битые записи пропускаются', () {
      final b = RingHistoryBuilder();
      b.addRecords('temperature', [
        {'date': '', 'temperature': '36.6'},
        {'date': '2026-07-10 04:00:00', 'temperature': 'abc'},
        {'date': '2026-07-10 04:00:00', 'temperature': '36.8'},
      ]);
      final h = b.build();

      expect(h.samples[HealthMetric.bodyTemperature], hasLength(1));
    });
  });
}
