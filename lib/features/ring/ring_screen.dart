import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/ring/ring_models.dart';
import '../../data/ring/ring_providers.dart';
import '../../data/ring/ring_service.dart';

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

  Future<void> _scan(RingService service) async {
    // На мобильных запрашиваем BLE-разрешения; на вебе пропускаем.
    if (!kIsWeb) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    }
    await service.startScan();
  }

  List<Widget> _scanBody(BuildContext context, WidgetRef ref, service,
      RingConnState conn) {
    final scan = ref.watch(ringScanProvider).value ?? const [];
    return [
      FilledButton.icon(
        onPressed:
            conn == RingConnState.scanning ? null : () => _scan(service),
        icon: const Icon(Icons.bluetooth_searching),
        label: Text(conn == RingConnState.scanning
            ? 'Поиск…'
            : 'Искать устройства'),
      ),
      const SizedBox(height: 16),
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
                onTap: () => service.connect(d.id),
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
      OutlinedButton.icon(
        onPressed: service.disconnect,
        icon: const Icon(Icons.bluetooth_disabled),
        label: const Text('Отключить'),
      ),
    ];
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
