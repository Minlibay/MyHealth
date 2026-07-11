import '../core/metric_source.dart';

/// Фаза сна.
enum SleepStageType {
  deep('deep', 'Глубокий'),
  light('light', 'Лёгкий'),
  rem('rem', 'REM'),
  awake('awake', 'Бодрствование');

  const SleepStageType(this.apiKey, this.label);
  final String apiKey;
  final String label;

  static SleepStageType? fromApi(String? raw) {
    for (final t in values) {
      if (t.apiKey == raw) return t;
    }
    return null;
  }
}

/// Один сегмент фазы внутри сессии сна.
class SleepStage {
  const SleepStage({required this.stage, required this.start, required this.end});

  final SleepStageType stage;
  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);
}

/// Сессия сна с фазами (кольцо или сервер).
class SleepSessionModel {
  const SleepSessionModel({
    required this.start,
    required this.end,
    this.stages = const [],
    this.source,
  });

  final DateTime start;
  final DateTime end;
  final List<SleepStage> stages;
  final MetricSource? source;

  Duration hoursOf(SleepStageType type) => stages
      .where((s) => s.stage == type)
      .fold(Duration.zero, (acc, s) => acc + s.duration);

  /// Чистый сон = вся сессия минус бодрствование.
  Duration get asleep => end.difference(start) - hoursOf(SleepStageType.awake);
}
