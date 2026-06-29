/// Найденное при сканировании устройство (кольцо).
class RingDevice {
  const RingDevice({required this.id, required this.name, this.rssi});

  /// MAC (Android) или UUID (iOS) — идентификатор для подключения.
  final String id;
  final String name;
  final int? rssi;

  factory RingDevice.fromMap(Map<dynamic, dynamic> m) => RingDevice(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? 'Кольцо',
        rssi: (m['rssi'] as num?)?.toInt(),
      );
}

/// Состояние подключения к кольцу.
enum RingConnState { disconnected, scanning, connecting, connected, failed }

/// Снимок текущих живых показателей с кольца.
class RingLiveData {
  const RingLiveData({
    this.heartRate,
    this.spo2,
    this.temperature,
    this.hrv,
    this.battery,
    this.steps,
    required this.time,
  });

  final int? heartRate; // уд/мин
  final int? spo2; // %
  final double? temperature; // °C
  final int? hrv; // мс
  final int? battery; // %
  final int? steps;
  final DateTime time;

  RingLiveData merge(Map<dynamic, dynamic> m) => RingLiveData(
        heartRate: (m['heartRate'] as num?)?.toInt() ?? heartRate,
        spo2: (m['spo2'] as num?)?.toInt() ?? spo2,
        temperature: (m['temperature'] as num?)?.toDouble() ?? temperature,
        hrv: (m['hrv'] as num?)?.toInt() ?? hrv,
        battery: (m['battery'] as num?)?.toInt() ?? battery,
        steps: (m['steps'] as num?)?.toInt() ?? steps,
        time: DateTime.now(),
      );
}
