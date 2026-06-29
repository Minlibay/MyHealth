import 'health_repository.dart';
// На Web (нет dart.library.io) берём фейковый источник, иначе — реальный
// поверх пакета `health`. Так веб-сборка вообще не тянет `health`/`dart:io`.
import 'health_service_fake.dart'
    if (dart.library.io) 'health_service_real.dart' as impl;

HealthRepository createHealthRepository() => impl.createHealthRepository();
