import 'ring_history.dart';
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

  /// [showAll] = true — показывать все BLE-устройства с именем, а не только
  /// похожие на кольцо/браслет Jstyle (на случай нестандартного имени).
  Future<void> startScan({bool showAll});
  Future<void> stopScan();

  /// [auto] = true — фоновое переподключение к известному устройству
  /// (после перезапуска приложения): соединение поднимется само, когда
  /// кольцо окажется в зоне действия.
  Future<void> connect(String deviceId, {bool auto});
  Future<void> disconnect();

  /// Запросить разовое измерение (пульс/SpO₂/температура).
  Future<void> measure();

  /// Выкачать накопленную историю с кольца (сон по фазам, пульс, HRV,
  /// SpO₂, температура, активность). Кольцо должно быть подключено.
  /// [deviceName] попадает в атрибуцию источника записей.
  Future<RingHistory> fetchHistory({String? deviceName});

  /// Включить автозамеры на кольце (интервал в минутах) — без них
  /// история не накапливается.
  Future<void> enableAutoMonitoring({int intervalMinutes});

  /// Записать профиль пользователя в кольцо (точность калорий).
  Future<void> setProfile({
    required int gender,
    required int age,
    required int height,
    required int weight,
  });

  void dispose();
}
