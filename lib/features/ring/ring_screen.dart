import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:intl/intl.dart';

import '../../data/ring/ring_connection.dart';
import '../../data/ring/ring_models.dart';
import '../../data/ring/ring_providers.dart';
import '../../data/ring/ring_service.dart';
import '../../data/ring/ring_sync.dart';

/// Показывать при поиске все BLE-устройства, а не только похожие на
/// кольцо/браслет (на случай нестандартного имени устройства).
class ShowAllDevicesController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final showAllDevicesProvider =
    NotifierProvider<ShowAllDevicesController, bool>(
        ShowAllDevicesController.new);

class RingScreen extends ConsumerWidget {
  const RingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(ringConnectionProvider).value ??
        RingConnState.disconnected;
    final service = ref.read(ringServiceProvider);
    final connected = conn == RingConnState.connected;

    return Scaffold(
      appBar: AppBar(title: const Text('Кольцо JCRing X3')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusBanner(state: conn),
          const SizedBox(height: 16),
          if (connected)
            ..._connectedBody(context, ref, service)
          else
            ..._scanBody(context, ref, service, conn),
        ],
      ),
    );
  }

  Future<void> _scan(RingService service, {required bool showAll}) async {
    // BLE-разрешения различаются по платформам; на вебе пропускаем.
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse, // нужно только до Android 12
        ].request();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Permission.bluetooth.request();
      }
    }
    await service.startScan(showAll: showAll);
  }

  List<Widget> _scanBody(BuildContext context, WidgetRef ref, service,
      RingConnState conn) {
    final scan = ref.watch(ringScanProvider).value ?? const [];
    final showAll = ref.watch(showAllDevicesProvider);
    final saved = ref.watch(ringDevicesProvider).value;
    return [
      // Сохранённые устройства: подключение в одно касание, без скана.
      if (saved != null && saved.devices.isNotEmpty) ...[
        Text('Мои устройства',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        ...saved.devices.map((d) => Card(
              child: ListTile(
                leading: Icon(
                  d.id == saved.activeId
                      ? Icons.radio_button_checked
                      : Icons.watch_rounded,
                  color: d.id == saved.activeId
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(d.name),
                subtitle:
                    Text(d.id == saved.activeId ? 'Активное' : 'Сохранено'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Забыть устройство',
                  onPressed: () => ref
                      .read(ringDevicesProvider.notifier)
                      .forget(d.id),
                ),
                onTap: () => ref
                    .read(ringDevicesProvider.notifier)
                    .connectAndRemember(d),
              ),
            )),
        const SizedBox(height: 16),
      ],
      FilledButton.icon(
        onPressed: conn == RingConnState.scanning
            ? null
            : () => _scan(service, showAll: showAll),
        icon: const Icon(Icons.bluetooth_searching),
        label: Text(conn == RingConnState.scanning
            ? 'Поиск…'
            : 'Искать устройства'),
      ),
      SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: const Text('Показать все устройства'),
        subtitle: const Text(
            'Если кольцо или браслет не находится — у него может быть '
            'нестандартное имя.'),
        value: showAll,
        onChanged: (v) {
          ref.read(showAllDevicesProvider.notifier).set(v);
          if (conn != RingConnState.scanning) _scan(service, showAll: v);
        },
      ),
      const SizedBox(height: 8),
      if (scan.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('Устройства не найдены. Включите кольцо рядом.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ),
        )
      else
        ...scan.map((d) => Card(
              child: ListTile(
                leading: const Icon(Icons.radio_button_checked),
                title: Text(d.name),
                subtitle: Text(d.id),
                trailing: d.rssi != null ? Text('${d.rssi} dBm') : null,
                // Запоминаем устройство — при следующем запуске
                // подключимся сами.
                onTap: () => ref
                    .read(ringDevicesProvider.notifier)
                    .connectAndRemember(d),
              ),
            )),
    ];
  }

  List<Widget> _connectedBody(BuildContext context, WidgetRef ref, service) {
    final live = ref.watch(ringLiveDataProvider).value;
    final tiles = <Widget>[
      _LiveTile(
          icon: Icons.favorite_rounded,
          label: 'Пульс',
          value: live?.heartRate?.toString(),
          unit: 'уд/мин',
          color: const Color(0xFFF2496B)),
      _LiveTile(
          icon: Icons.air_rounded,
          label: 'SpO₂',
          value: live?.spo2?.toString(),
          unit: '%',
          color: const Color(0xFF06B6D4)),
      _LiveTile(
          icon: Icons.thermostat_rounded,
          label: 'Температура',
          value: live?.temperature?.toStringAsFixed(1),
          unit: '°C',
          color: const Color(0xFFFB923C)),
      _LiveTile(
          icon: Icons.monitor_heart_rounded,
          label: 'HRV',
          value: live?.hrv?.toString(),
          unit: 'мс',
          color: const Color(0xFF8B5CF6)),
      _LiveTile(
          icon: Icons.battery_full_rounded,
          label: 'Батарея',
          value: live?.battery?.toString(),
          unit: '%',
          color: const Color(0xFF14B8A6)),
      _LiveTile(
          icon: Icons.directions_walk_rounded,
          label: 'Шаги',
          value: live?.steps?.toString(),
          unit: '',
          color: const Color(0xFF4F6DF5)),
    ];

    return [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: tiles,
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: service.measure,
        icon: const Icon(Icons.refresh),
        label: const Text('Измерить сейчас'),
      ),
      const SizedBox(height: 8),
      _HistorySyncButton(ref: ref),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        // Разрыв соединения; устройство остаётся в «Моих устройствах».
        onPressed: service.disconnect,
        icon: const Icon(Icons.bluetooth_disabled),
        label: const Text('Отключить'),
      ),
    ];
  }
}

/// Кнопка выкачивания истории с кольца + статус последней синхронизации.
class _HistorySyncButton extends StatelessWidget {
  const _HistorySyncButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sync = ref.watch(ringSyncProvider);
    final syncing = sync.phase == RingSyncPhase.syncing;

    // Разбивка по типам — видно, какие данные кольцо реально отдало.
    const kindLabels = {
      'activity': 'активность',
      'sleep': 'сон',
      'dynamicHr': 'пульс',
      'staticHr': 'пульс разовый',
      'hrv': 'HRV',
      'spo2': 'SpO₂',
      'temperature': 'темп.',
      'sleepTemperature': 'темп. сна',
      'osa': 'апноэ',
    };
    final counts = sync.history?.rawCounts;
    var breakdown = counts == null || counts.isEmpty
        ? ''
        : '\n${kindLabels.entries.map((e) => '${e.value} ${counts[e.key] ?? 0}').join(' · ')}';
    // Поля записи сна — по ним видно, что реально шлёт SDK, если фазы
    // не распознались.
    final sleepKeys = sync.history?.sampleKeys['sleep'];
    if (sleepKeys != null && (sync.history?.sleepSessions.isEmpty ?? true)) {
      breakdown += '\nПоля сна: $sleepKeys';
    }
    final osa = sync.history?.osaRisks;
    if (osa != null && osa.isNotEmpty) {
      final label = switch (osa.first.risk) {
        0 || 1 => 'низкий риск',
        2 => 'умеренный риск',
        _ => 'высокий риск — обсудите с врачом',
      };
      breakdown += '\nАпноэ за ночь: $label';
    }

    final subtitle = switch (sync.phase) {
      RingSyncPhase.syncing => 'Выкачиваем историю с кольца…',
      RingSyncPhase.done =>
        'Записей: ${sync.records} · ${DateFormat.Hm().format(sync.at!)}$breakdown',
      RingSyncPhase.error => 'Ошибка: ${sync.message}',
      RingSyncPhase.idle => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          onPressed: syncing
              ? null
              : () => ref.read(ringSyncProvider.notifier).syncNow(),
          icon: syncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.history_rounded),
          label: const Text('Синхронизировать историю'),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: sync.phase == RingSyncPhase.error
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state});
  final RingConnState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (text, color, icon) = switch (state) {
      RingConnState.connected => (
          'Подключено',
          theme.colorScheme.primary,
          Icons.bluetooth_connected
        ),
      RingConnState.connecting => (
          'Подключение…',
          theme.colorScheme.primary,
          Icons.bluetooth
        ),
      RingConnState.scanning => (
          'Поиск устройств…',
          theme.colorScheme.primary,
          Icons.bluetooth_searching
        ),
      RingConnState.failed => (
          'Не удалось подключиться',
          theme.colorScheme.error,
          Icons.error_outline
        ),
      RingConnState.disconnected => (
          'Не подключено',
          theme.colorScheme.outline,
          Icons.bluetooth_disabled
        ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(text,
              style: theme.textTheme.titleMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _LiveTile extends StatelessWidget {
  const _LiveTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.titleSmall),
            ]),
            RichText(
              text: TextSpan(
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: theme.colorScheme.onSurface),
                children: [
                  TextSpan(text: value ?? '—'),
                  if (unit.isNotEmpty)
                    TextSpan(
                        text: ' $unit',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
