import 'package:flutter_test/flutter_test.dart';
import 'package:myhealth/core/health_metric.dart';
import 'package:myhealth/core/health_status.dart';

void main() {
  group('statusFor', () {
    test('пульс в норме / повышен / критичен', () {
      expect(statusFor(HealthMetric.heartRate, 72), HealthStatus.ok);
      expect(statusFor(HealthMetric.heartRate, 105), HealthStatus.warn);
      expect(statusFor(HealthMetric.heartRate, 130), HealthStatus.alert);
    });

    test('давление учитывает обе границы', () {
      expect(statusFor(HealthMetric.bloodPressure, 120, 80), HealthStatus.ok);
      expect(statusFor(HealthMetric.bloodPressure, 134, 82), HealthStatus.warn);
      expect(statusFor(HealthMetric.bloodPressure, 145, 95), HealthStatus.alert);
    });

    test('SpO2 ниже порогов', () {
      expect(statusFor(HealthMetric.bloodOxygen, 98), HealthStatus.ok);
      expect(statusFor(HealthMetric.bloodOxygen, 93), HealthStatus.warn);
      expect(statusFor(HealthMetric.bloodOxygen, 88), HealthStatus.alert);
    });

    test('шаги и вес не оцениваются', () {
      expect(statusFor(HealthMetric.steps, 5000), HealthStatus.unknown);
      expect(statusFor(HealthMetric.weight, 74), HealthStatus.unknown);
    });

    test('нет значения — статус неизвестен', () {
      expect(statusFor(HealthMetric.heartRate, null), HealthStatus.unknown);
    });
  });
}
