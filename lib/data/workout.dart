import '../core/metric_source.dart';

/// Одна тренировка из HealthKit / Health Connect или с сервера.
class Workout {
  const Workout({
    required this.activityType,
    required this.start,
    required this.end,
    this.energyKcal,
    this.distanceMeters,
    this.source,
    this.avgHr,
    this.maxHr,
    this.zonesMinutes,
    this.trimp,
  });

  /// Сырое имя типа активности (enum пакета health / бэкенда), напр. "RUNNING".
  final String activityType;

  final DateTime start;
  final DateTime end;

  /// Сожжённые калории, если известны.
  final double? energyKcal;

  /// Дистанция в метрах, если известна.
  final double? distanceMeters;

  final MetricSource? source;

  /// Аналитика с сервера (по пульсу за окно тренировки), если рассчитана.
  final double? avgHr;
  final double? maxHr;

  /// Минуты в зонах пульса Z1..Z5.
  final List<double>? zonesMinutes;

  /// Нагрузка по Эдвардсу: Σ минут в зоне × номер зоны.
  final double? trimp;

  Duration get duration => end.difference(start);

  /// Русское название типа активности; для незнакомых — облагороженное сырое.
  String get title =>
      _activityTitles[activityType] ??
      activityType
          .toLowerCase()
          .replaceAll('_', ' ')
          .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());
}

const Map<String, String> _activityTitles = {
  'RUNNING': 'Бег',
  'RUNNING_TREADMILL': 'Бег (дорожка)',
  'WALKING': 'Ходьба',
  'HIKING': 'Поход',
  'BIKING': 'Велосипед',
  'SWIMMING': 'Плавание',
  'SWIMMING_POOL': 'Плавание (бассейн)',
  'SWIMMING_OPEN_WATER': 'Плавание (открытая вода)',
  'YOGA': 'Йога',
  'PILATES': 'Пилатес',
  'STRENGTH_TRAINING': 'Силовая',
  'TRADITIONAL_STRENGTH_TRAINING': 'Силовая',
  'FUNCTIONAL_STRENGTH_TRAINING': 'Функциональная',
  'HIGH_INTENSITY_INTERVAL_TRAINING': 'HIIT',
  'ELLIPTICAL': 'Эллипс',
  'ROWING': 'Гребля',
  'STAIR_CLIMBING': 'Лестница',
  'TENNIS': 'Теннис',
  'BADMINTON': 'Бадминтон',
  'BASKETBALL': 'Баскетбол',
  'SOCCER': 'Футбол',
  'AMERICAN_FOOTBALL': 'Амер. футбол',
  'VOLLEYBALL': 'Волейбол',
  'BOXING': 'Бокс',
  'MARTIAL_ARTS': 'Единоборства',
  'DANCING': 'Танцы',
  'GYMNASTICS': 'Гимнастика',
  'SKIING': 'Лыжи',
  'DOWNHILL_SKIING': 'Горные лыжи',
  'CROSS_COUNTRY_SKIING': 'Беговые лыжи',
  'SNOWBOARDING': 'Сноуборд',
  'SKATING': 'Коньки',
  'GOLF': 'Гольф',
  'TABLE_TENNIS': 'Наст. теннис',
  'CLIMBING': 'Скалолазание',
  'COOLDOWN': 'Заминка',
  'CORE_TRAINING': 'Пресс/кор',
  'CROSS_TRAINING': 'Кросс-тренинг',
  'MEDITATION': 'Медитация',
  'OTHER': 'Тренировка',
};
