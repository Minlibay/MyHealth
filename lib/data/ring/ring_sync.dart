import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../sync_settings.dart';
import 'ring_connection.dart';
import 'ring_history.dart';
import 'ring_models.dart';
import 'ring_providers.dart';

// cloudModeProvider и провайдеры данных живут в providers.dart.
import '../../providers.dart'
    show
        cloudModeProvider,
        insightsProvider,
        metricSeriesProvider,
        readingsProvider,
        sleepSessionsProvider;

enum RingSyncPhase { idle, syncing, done, error }

class RingSyncState {
  const RingSyncState(this.phase,
      {this.at, this.records, this.message, this.history});

  final RingSyncPhase phase;
  final DateTime? at;

  /// Сколько записей выкачано с кольца за последнюю синхронизацию.
  final int? records;
  final String? message;

  /// Последняя выкачанная история — источник гипнограммы в локальном режиме.
  final RingHistory? history;
}

/// Выкачивает историю с кольца и выгружает её на сервер (source=ring).
/// При подключении кольца включает автозамеры — без них истории не будет.
class RingSyncController extends Notifier<RingSyncState> {
  @override
  RingSyncState build() {
    ref.listen(ringConnectionProvider, (prev, next) {
      if (next.value == RingConnState.connected &&
          prev?.value != RingConnState.connected) {
        // Интервал 15 минут — компромисс между детализацией и батареей.
        ref
            .read(ringServiceProvider)
            .enableAutoMonitoring(intervalMinutes: 15)
            .catchError((_) {});
        // Все накопленные замеры подтягиваются сразу при подключении;
        // пауза даёт живому потоку и конфигурации встать в очередь первыми.
        Future.delayed(const Duration(seconds: 3), () {
          if (ref.read(ringConnectionProvider).value ==
              RingConnState.connected) {
            syncNow();
          }
        });
      }
    });
    return const RingSyncState(RingSyncPhase.idle);
  }

  Future<void> syncNow() async {
    if (state.phase == RingSyncPhase.syncing) return;
    state = const RingSyncState(RingSyncPhase.syncing);
    try {
      final deviceName = ref.read(ringDevicesProvider).value?.active?.name;
      final history = await ref
          .read(ringServiceProvider)
          .fetchHistory(deviceName: deviceName);

      // Выгрузку с кольца можно выключить в настройках синхронизации;
      // локально история (гипнограмма) остаётся доступной в любом случае.
      if (ref.read(cloudModeProvider) &&
          ref.read(syncSettingsProvider).ring &&
          !history.isEmpty) {
        final api = ref.read(metricsApiProvider);
        for (final entry in history.samples.entries) {
          await api.uploadSamples(entry.key, entry.value);
        }
        await ref
            .read(sleepApiProvider)
            .uploadSessions(history.sleepSessions);
        ref.invalidate(readingsProvider);
        ref.invalidate(metricSeriesProvider);
        ref.invalidate(sleepSessionsProvider);
        ref.invalidate(insightsProvider);
      }

      state = RingSyncState(
        RingSyncPhase.done,
        at: DateTime.now(),
        records: history.totalRecords,
        history: history,
      );
    } catch (e) {
      state = RingSyncState(RingSyncPhase.error,
          at: DateTime.now(), message: '$e', history: state.history);
    }
  }
}

final ringSyncProvider = NotifierProvider<RingSyncController, RingSyncState>(
    RingSyncController.new);
