import 'package:flutter_test/flutter_test.dart';
import 'package:myhealth/core/health_status.dart';

void main() {
  group('HealthStatus.fromApi', () {
    test('парсит значения enum с бэкенда', () {
      expect(HealthStatus.fromApi('Ok'), HealthStatus.ok);
      expect(HealthStatus.fromApi('Warn'), HealthStatus.warn);
      expect(HealthStatus.fromApi('Alert'), HealthStatus.alert);
      expect(HealthStatus.fromApi('Unknown'), HealthStatus.unknown);
    });

    test('неизвестное/пустое → unknown', () {
      expect(HealthStatus.fromApi(null), HealthStatus.unknown);
      expect(HealthStatus.fromApi('whatever'), HealthStatus.unknown);
    });

    test('isMeaningful', () {
      expect(HealthStatus.ok.isMeaningful, isTrue);
      expect(HealthStatus.unknown.isMeaningful, isFalse);
    });
  });
}
