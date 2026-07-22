import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/health_repository.dart';
import '../../providers.dart';

/// Диагностика хранилища здоровья: что реально доступно и какие приложения
/// (Fitbit, Google Fit, Samsung Health...) пишут туда данные. Помогает
/// понять, почему показатель «не виден» — нет разрешения или источник
/// вообще ничего не записал в хранилище.
class HealthDiagnosticsScreen extends ConsumerWidget {
  const HealthDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final diag = ref.watch(healthDiagnosticsProvider);
    final storeName = defaultTargetPlatform == TargetPlatform.iOS
        ? 'Apple Health'
        : 'Health Connect';

    return Scaffold(
      appBar: AppBar(title: const Text('Диагностика данных')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(healthDiagnosticsProvider);
          await ref.read(healthDiagnosticsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Как это работает', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(
                      'Приложение читает данные из $storeName. Fitbit и Google '
                      'Health видны, только если они сами записывают данные в '
                      '$storeName. Ниже — что реально доступно за 7 дней.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (defaultTargetPlatform == TargetPlatform.android) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Если Fitbit пуст: откройте приложение Fitbit / Google '
                        'Health → Настройки → Health Connect и включите запись '
                        'нужных типов данных. Затем нажмите «Обновить доступ».',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await ref
                            .read(deviceRepositoryProvider)
                            .requestPermissions();
                        ref.invalidate(healthDiagnosticsProvider);
                        messenger.showSnackBar(const SnackBar(
                            content: Text('Доступ обновлён')));
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Обновить доступ'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            diag.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Ошибка: $e', textAlign: TextAlign.center),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Диагностика доступна только на устройстве с хранилищем '
                      'здоровья (Android/iOS).',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return Card(
                  child: Column(
                    children: [
                      for (final (i, r) in rows.indexed) ...[
                        if (i > 0)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        _DiagRow(row: r),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow({required this.row});

  final MetricDiagnostic row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch ((row.available, row.recordCount)) {
      (false, _) => (Icons.block_rounded, theme.colorScheme.outline),
      (true, 0) => (Icons.remove_circle_outline_rounded,
          theme.colorScheme.error),
      _ => (Icons.check_circle_rounded, const Color(0xFF22C55E)),
    };
    final subtitle = !row.available
        ? 'Недоступно на этой платформе'
        : row.recordCount == 0
            ? 'Нет данных в хранилище'
            : '${row.recordCount} записей · ${row.sources.isEmpty ? 'источник неизвестен' : row.sources.join(', ')}';

    return ListTile(
      leading: Icon(row.metric.icon, color: row.metric.color),
      title: Text(row.metric.title),
      subtitle: Text(subtitle),
      trailing: Icon(icon, color: color, size: 20),
    );
  }
}
