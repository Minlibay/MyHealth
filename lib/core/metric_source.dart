/// Тип источника измерения. Определяется платформой и способом подключения:
/// хранилище на iOS — Apple Health, на Android — Health Connect (на чужой
/// платформе они не встречаются), кольцо подключается по BLE на обеих.
enum MetricSourceType {
  appleHealth('apple_health', 'Apple Health'),
  healthConnect('health_connect', 'Health Connect'),
  ring('ring', 'Кольцо'),
  manual('manual', 'Ручной ввод'),
  demo('demo', 'Демо'),
  other('other', 'Другой источник');

  const MetricSourceType(this.apiKey, this.label);

  /// Ключ в поле Source на сервере.
  final String apiKey;

  /// Короткая подпись для UI.
  final String label;
}

/// Источник измерения: тип + уточнение — какое приложение или устройство
/// записало данные в хранилище (например, «Apple Watch» внутри Apple Health)
/// или модель кольца.
class MetricSource {
  const MetricSource(this.type, [this.detail]);

  static const ring = MetricSource(MetricSourceType.ring, 'JCRing X3');
  static const manual = MetricSource(MetricSourceType.manual);
  static const demo = MetricSource(MetricSourceType.demo);

  final MetricSourceType type;
  final String? detail;

  /// Полная подпись для UI: «Apple Health · Apple Watch».
  String get label {
    final d = detail;
    if (d == null || d.isEmpty || d == type.label) return type.label;
    return '${type.label} · $d';
  }

  /// Формат поля Source на сервере: "apple_health:Apple Watch".
  String toApi() {
    final d = detail;
    return (d == null || d.isEmpty) ? type.apiKey : '${type.apiKey}:$d';
  }

  /// Парсит формат [toApi]; незнакомые строки (старые записи) сохраняет
  /// как detail с типом other, null/пустое → null.
  static MetricSource? fromApi(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final i = raw.indexOf(':');
    final key = i < 0 ? raw : raw.substring(0, i);
    final detail = i < 0 ? null : raw.substring(i + 1);
    for (final t in MetricSourceType.values) {
      if (t.apiKey == key) {
        return MetricSource(t, (detail?.isEmpty ?? true) ? null : detail);
      }
    }
    return MetricSource(MetricSourceType.other, raw);
  }
}
