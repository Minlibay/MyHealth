/// Тип источника измерения. Определяется платформой и способом подключения:
/// хранилище на iOS — Apple Health, на Android — Health Connect (на чужой
/// платформе они не встречаются), кольцо подключается по BLE на обеих.
enum MetricSourceType {
  appleHealth('apple_health', 'Apple Health'),
  healthConnect('health_connect', 'Health Connect'),
  googleHealth('google_health', 'Google Health'),
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

  /// Приложения-компаньоны кольца/браслета Jstyle. Данные, записанные ими
  /// в Apple Health / Health Connect, по сути идут с нашего устройства —
  /// показываем как само приложение, без префикса хранилища.
  static const _ringApps = ['jcvitalpro', 'jcring', 'jstyle', 'j-style'];

  /// Только для хранилищ: если данные записало приложение кольца — считаем
  /// их «нашими». Для самого типа ring подпись не меняем.
  bool get _isRingApp {
    const stores = {
      MetricSourceType.appleHealth,
      MetricSourceType.healthConnect,
      MetricSourceType.googleHealth,
    };
    if (!stores.contains(type)) return false;
    final d = detail?.toLowerCase();
    return d != null && _ringApps.any(d.contains);
  }

  /// Полная подпись для UI: «Apple Health · Apple Watch».
  /// Для приложений кольца — только имя приложения («JCVitalPro»).
  String get label {
    final d = detail;
    if (d == null || d.isEmpty || d == type.label) return type.label;
    if (_isRingApp) return d;
    return '${type.label} · $d';
  }

  /// Короткая подпись (карточка метрики): для приложений кольца — имя
  /// приложения, иначе — название источника.
  String get shortLabel => _isRingApp ? detail! : type.label;

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
