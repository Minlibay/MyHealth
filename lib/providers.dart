import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/health_metric.dart';
import 'data/api/api_health_repository.dart';
import 'data/auth/auth_controller.dart';
import 'data/health_repository.dart';
import 'data/health_repository_factory.dart';
import 'data/insights.dart';
import 'data/metric_reading.dart';
import 'data/metric_sample.dart';
import 'data/sleep_session.dart';
import 'data/workout.dart';

/// Источник данных устройства: фейковый на Web, реальный (HealthKit/Health
/// Connect) на мобильных. Используется для отображения без входа и как
/// источник для синхронизации в облако.
final deviceRepositoryProvider =
    Provider<HealthRepository>((ref) => createHealthRepository());

/// Источник данных из облака (сервер). Доступен после входа.
final cloudRepositoryProvider = Provider<HealthRepository>((ref) =>
    ApiHealthRepository(
        ref.watch(metricsApiProvider), ref.watch(workoutsApiProvider)));

/// Облачный режим включён, когда пользователь вошёл в аккаунт.
final cloudModeProvider = Provider<bool>(
    (ref) => ref.watch(authControllerProvider).value != null);

/// Активный источник для дашборда: облако (если вошёл) либо устройство.
final activeRepositoryProvider = Provider<HealthRepository>((ref) =>
    ref.watch(cloudModeProvider)
        ? ref.watch(cloudRepositoryProvider)
        : ref.watch(deviceRepositoryProvider));

/// Согласие пользователя на обработку данных о здоровье (GDPR).
/// Хранится локально; до явного согласия данные не запрашиваются.
class ConsentController extends AsyncNotifier<bool> {
  static const _key = 'gdpr_consent_v1';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> grant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    state = const AsyncData(true);
  }

  Future<void> revoke() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = const AsyncData(false);
  }
}

final consentControllerProvider =
    AsyncNotifierProvider<ConsentController, bool>(ConsentController.new);

/// Завершён ли онбординг (показывается один раз перед экраном согласия).
class OnboardingController extends AsyncNotifier<bool> {
  static const _key = 'onboarding_done_v1';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    state = const AsyncData(true);
  }
}

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, bool>(OnboardingController.new);

/// Режим темы (система/светлая/тёмная) с сохранением выбора.
class ThemeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode_v1';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v != null) {
      state = ThemeMode.values.firstWhere((m) => m.name == v,
          orElse: () => ThemeMode.system);
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

/// Доступность хранилища здоровья на устройстве (для гейтинга разрешений).
final healthAvailabilityProvider = FutureProvider<HealthAvailability>((ref) {
  return ref.watch(deviceRepositoryProvider).checkAvailability();
});

/// Последние значения по всем показателям из активного источника.
final readingsProvider =
    FutureProvider<Map<HealthMetric, MetricReading?>>((ref) {
  return ref.watch(activeRepositoryProvider).fetchLatestAll();
});

/// Аргумент для истории показателя: какой показатель и за сколько дней.
typedef SeriesArgs = ({HealthMetric metric, int days});

/// История одного показателя за период из активного источника.
final metricSeriesProvider =
    FutureProvider.family<List<MetricSample>, SeriesArgs>((ref, args) {
  return ref
      .watch(activeRepositoryProvider)
      .fetchSeries(args.metric, days: args.days);
});

/// Тренировки за период из активного источника (новые первыми).
final workoutsProvider = FutureProvider.family<List<Workout>, int>((ref, days) {
  return ref.watch(activeRepositoryProvider).fetchWorkouts(days: days);
});

/// Инсайты (скоры, базовые линии, тренды) — считает бэкенд.
/// Доступны только в облачном режиме.
final insightsProvider = FutureProvider<Insights?>((ref) async {
  if (!ref.watch(cloudModeProvider)) return null;
  return ref.watch(insightsApiProvider).fetch();
});

/// Сессии сна с фазами с сервера (облачный режим).
final sleepSessionsProvider =
    FutureProvider.family<List<SleepSessionModel>, int>((ref, days) async {
  if (!ref.watch(cloudModeProvider)) return const [];
  return ref.watch(sleepApiProvider).fetchSessions(days: days);
});

/// Фаза синхронизации с сервером.
enum SyncPhase { idle, syncing, synced, error }

class SyncStatus {
  const SyncStatus(this.phase, {this.at, this.inserted, this.message});
  final SyncPhase phase;
  final DateTime? at;
  final int? inserted;
  final String? message;
}

/// Выгружает данные устройства на сервер и обновляет облачный дашборд.
class SyncController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus(SyncPhase.idle);

  Future<void> syncNow() async {
    if (!ref.read(cloudModeProvider)) return;
    if (state.phase == SyncPhase.syncing) return;
    state = const SyncStatus(SyncPhase.syncing);
    try {
      final device = ref.read(deviceRepositoryProvider);
      final api = ref.read(metricsApiProvider);
      // В облачном режиме гейтинг разрешений на дашборде пропускается,
      // а чтение HealthKit без выданного доступа бросает
      // "Authorization not determined" — запрашиваем перед синхронизацией
      // (если доступ уже выдан, iOS/Android ничего не показывают).
      try {
        await device.requestPermissions();
      } catch (_) {}
      var total = 0;
      for (final metric in HealthMetric.values) {
        // Одна недоступная метрика (нет разрешения/типа на платформе)
        // не должна отменять синхронизацию остальных.
        final List<MetricSample> series;
        try {
          series = await device.fetchSeries(metric, days: 30);
        } catch (_) {
          continue;
        }
        total += await api.uploadSamples(metric, series);
      }
      // Тренировки выгружаются вместе с показателями.
      List<Workout> workouts = const [];
      try {
        workouts = await device.fetchWorkouts(days: 30);
      } catch (_) {}
      total += await ref.read(workoutsApiProvider).uploadWorkouts(workouts);
      state = SyncStatus(SyncPhase.synced, at: DateTime.now(), inserted: total);
      // Обновляем облачные данные на дашборде.
      ref.invalidate(readingsProvider);
      ref.invalidate(metricSeriesProvider);
      ref.invalidate(workoutsProvider);
      ref.invalidate(insightsProvider);
      ref.invalidate(sleepSessionsProvider);
    } catch (e) {
      state = SyncStatus(SyncPhase.error, at: DateTime.now(), message: '$e');
    }
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncStatus>(SyncController.new);
