import 'ring_models.dart';

/// Абстракция над подключением к кольцу JCRing X3.
/// Реализации: нативная (BLE через платформенный канал) и фейковая (web/dev).
abstract class RingService {
  /// Найденные при сканировании устройства.
  Stream<List<RingDevice>> get scanResults;

  /// Текущее состояние подключения.
  Stream<RingConnState> get connectionState;

  /// Поток живых показателей.
  Stream<RingLiveData> get liveData;

  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connect(String deviceId);
  Future<void> disconnect();

  /// Запросить разовое измерение (пульс/SpO₂/температура).
  Future<void> measure();

  void dispose();
}
