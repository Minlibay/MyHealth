// Локальные уведомления об аномалиях. На Web уведомлений нет — заглушка.
export 'notifications_stub.dart'
    if (dart.library.io) 'notifications_io.dart';
