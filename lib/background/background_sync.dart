// Фоновая синхронизация показателей с сервером.
// На Web фоновых задач нет — подключается заглушка.
export 'background_sync_stub.dart'
    if (dart.library.io) 'background_sync_io.dart';
