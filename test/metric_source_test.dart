import 'package:flutter_test/flutter_test.dart';
import 'package:myhealth/core/health_metric.dart';
import 'package:myhealth/core/metric_source.dart';
import 'package:myhealth/data/metric_reading.dart';

void main() {
  group('MetricSource.toApi/fromApi', () {
    test('сериализация с detail и без', () {
      expect(
        const MetricSource(MetricSourceType.appleHealth, 'Apple Watch').toApi(),
        'apple_health:Apple Watch',
      );
      expect(
        const MetricSource(MetricSourceType.healthConnect).toApi(),
        'health_connect',
      );
      expect(MetricSource.ring.toApi(), 'ring:JCRing X3');
    });

    test('круговой парсинг', () {
      for (final source in [
        const MetricSource(MetricSourceType.appleHealth, 'Mi Fitness'),
        const MetricSource(MetricSourceType.healthConnect),
        MetricSource.ring,
        MetricSource.demo,
      ]) {
        final parsed = MetricSource.fromApi(source.toApi());
        expect(parsed!.type, source.type);
        expect(parsed.detail, source.detail);
      }
    });

    test('null/пустое → null, незнакомое → other с исходной строкой', () {
      expect(MetricSource.fromApi(null), isNull);
      expect(MetricSource.fromApi(''), isNull);
      final legacy = MetricSource.fromApi('Кольцо JCRing X3');
      expect(legacy!.type, MetricSourceType.other);
      expect(legacy.detail, 'Кольцо JCRing X3');
    });

    test('label собирается из типа и detail', () {
      expect(
        const MetricSource(MetricSourceType.appleHealth, 'Apple Watch').label,
        'Apple Health · Apple Watch',
      );
      expect(const MetricSource(MetricSourceType.healthConnect).label,
          'Health Connect');
      expect(MetricSource.ring.label, 'Кольцо · JCRing X3');
    });

    test('приложения кольца показываются без префикса хранилища', () {
      final s = MetricSource.fromApi('apple_health:JCVitalPro')!;
      expect(s.type, MetricSourceType.appleHealth);
      expect(s.label, 'JCVitalPro');
      expect(s.shortLabel, 'JCVitalPro');
    });

    test('google_health распознаётся как отдельный источник', () {
      final s = MetricSource.fromApi('google_health')!;
      expect(s.type, MetricSourceType.googleHealth);
      expect(s.label, 'Google Health');
    });
  });

  group('preferFresher', () {
    MetricReading reading(DateTime time) => MetricReading(
          metric: HealthMetric.heartRate,
          displayValue: '70',
          value: 70,
          time: time,
        );

    test('null проигрывает', () {
      final r = reading(DateTime(2026, 7, 10));
      expect(preferFresher(null, r), r);
      expect(preferFresher(r, null), r);
      expect(preferFresher(null, null), isNull);
    });

    test('побеждает более свежее чтение', () {
      final old = reading(DateTime(2026, 7, 10, 8));
      final fresh = reading(DateTime(2026, 7, 10, 12));
      expect(preferFresher(old, fresh), fresh);
      expect(preferFresher(fresh, old), fresh);
    });

    test('при равном времени побеждает второй аргумент (живой источник)', () {
      final a = reading(DateTime(2026, 7, 10, 8));
      final b = reading(DateTime(2026, 7, 10, 8));
      expect(preferFresher(a, b), b);
    });
  });
}
