import '../../core/health_metric.dart';
import '../health_repository.dart';
import '../metric_reading.dart';
import '../metric_sample.dart';
import '../workout.dart';
import 'metrics_api.dart';
import 'workouts_api.dart';

/// Реализация [HealthRepository], читающая данные с сервера (облако).
/// Разрешения/доступность не применимы — данные приходят по сети.
class ApiHealthRepository implements HealthRepository {
  ApiHealthRepository(this._api, this._workoutsApi);
  final MetricsApi _api;
  final WorkoutsApi _workoutsApi;

  @override
  Future<HealthAvailability> checkAvailability() async =>
      HealthAvailability.available;

  @override
  Future<void> installHealthConnect() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool?> hasPermissions() async => true;

  @override
  Future<void> revokePermissions() async {}

  @override
  Future<Map<HealthMetric, MetricReading?>> fetchLatestAll({int days = 7}) =>
      _api.fetchLatest();

  @override
  Future<List<MetricSample>> fetchSeries(HealthMetric metric, {int days = 7}) =>
      _api.fetchSeries(metric, days: days);

  @override
  Future<List<Workout>> fetchWorkouts({int days = 30}) =>
      _workoutsApi.fetchWorkouts(days: days);
}
