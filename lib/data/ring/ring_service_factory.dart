import 'ring_service.dart';
// Web (нет dart.library.io) → фейк; мобильные → нативный BLE.
import 'ring_service_fake.dart'
    if (dart.library.io) 'ring_service_native.dart' as impl;

RingService createRingService() => impl.createRingService();
