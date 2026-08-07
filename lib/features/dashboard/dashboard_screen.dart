import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/health_metric.dart';
import '../../data/health_repository.dart';
import '../../data/metric_reading.dart';
import '../../data/ring/ring_capture.dart';
import '../../data/ring/ring_models.dart';
import '../../data/ring/ring_providers.dart';
import '../../providers.dart';
import '../manual_entry/manual_entry_sheet.dart';
import '../tags/tag_sheet.dart';
import 'insights_card.dart';
import 'metric_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _requesting = false;
  bool? _granted;

  @override
  void initState() {
    super.initState();
    // Автоматически подтягиваем данные при открытии, если последняя
    // синхронизация была давно — вручную нажимать не нужно.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(cloudModeProvider)) return;
      final status = ref.read(syncControllerProvider);
      final stale = status.at == null ||
          DateTime.now().difference(status.at!) > const Duration(minutes: 30);
      if (stale && status.phase != SyncPhase.syncing) {
        ref.read(syncControllerProvider.notifier).syncNow();
      }
    });
  }

  Future<void> _requestAccess() async {
    setState(() => _requesting = true);
    final ok = await ref.read(deviceRepositoryProvider).requestPermissions();
    if (!mounted) return;
    setState(() {
      _granted = ok;
      _requesting = false;
    });
    if (ok) ref.invalidate(readingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cloudMode = ref.watch(cloudModeProvider);
    return Scaffold(
      body: SafeArea(
        // В облачном режиме данные приходят с сервера — гейтинг разрешений
        // устройства не нужен.
        child: cloudMode
            ? _buildDashboard()
            : ref.watch(healthAvailabilityProvider).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _Message(text: 'Ошибка: $e'),
                  data: _buildForAvailability,
                ),
      ),
    );
  }

  Widget _buildForAvailability(HealthAvailability status) {
    switch (status) {
      case HealthAvailability.unsupported:
        return const _Message(
          icon: Icons.phonelink_erase_rounded,
          text: 'Данные о здоровье доступны только на Android и iOS. '
              'Запустите приложение на телефоне.',
        );
      case HealthAvailability.needsInstall:
      case HealthAvailability.needsUpdate:
        return _Message(
          icon: Icons.download_rounded,
          text: status == HealthAvailability.needsInstall
              ? 'Для работы нужен Google Health Connect.'
              : 'Обновите Google Health Connect.',
          action: FilledButton(
            onPressed: () =>
                ref.read(deviceRepositoryProvider).installHealthConnect(),
            child: const Text('Открыть Play Store'),
          ),
        );
      case HealthAvailability.available:
        if (_granted == false) {
          return _Message(
            icon: Icons.lock_outline_rounded,
            text: 'Доступ к данным здоровья не предоставлен.',
            action: FilledButton(
              onPressed: _requesting ? null : _requestAccess,
              child: const Text('Повторить запрос'),
            ),
          );
        }
        if (_granted == null) {
          return _PermissionPrompt(
            requesting: _requesting,
            onRequest: _requestAccess,
          );
        }
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    final readings = ref.watch(readingsProvider);
    final cloudMode = ref.watch(cloudModeProvider);
    // Живые значения с кольца перекрывают базовый источник,
    // только если они свежее по времени измерения.
    final ringMap = ref.watch(ringCaptureProvider);
    return RefreshIndicator(
      onRefresh: () async {
        if (cloudMode) {
          // Сначала выгружаем свежие данные устройства, затем читаем облако.
          await ref.read(syncControllerProvider.notifier).syncNow();
        }
        ref.invalidate(readingsProvider);
        await ref.read(readingsProvider.future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          const SliverToBoxAdapter(child: _Header()),
          const SliverToBoxAdapter(child: InsightsCard()),
          const SliverToBoxAdapter(child: _WorkoutsTile()),
          readings.when(
            loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _Message(text: 'Не удалось прочитать данные: $e')),
            data: (map) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.86,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final metric = HealthMetric.values[i];
                    return MetricCard(
                      metric: metric,
                      reading: preferFresher(map[metric], ringMap[metric]),
                      onTap: () => context.push('/metric/${metric.name}'),
                    )
                        .animate()
                        .fadeIn(
                            delay: (60 * i).ms, duration: 350.ms)
                        .slideY(begin: 0.12, curve: Curves.easeOutCubic);
                  },
                  childCount: HealthMetric.values.length,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 5
        ? 'Доброй ночи'
        : hour < 12
            ? 'Доброе утро'
            : hour < 18
                ? 'Добрый день'
                : 'Добрый вечер';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 2),
                Text('Моё здоровье',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontSize: 30)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, d MMMM', 'ru').format(now),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [_SyncChip(), _RingChip()],
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            iconSize: 22,
            onPressed: () => showTagSheet(context),
            icon: const Icon(Icons.sell_outlined),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            iconSize: 22,
            onPressed: () => context.push('/compare'),
            icon: const Icon(Icons.ssid_chart_rounded),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            iconSize: 22,
            onPressed: () => showManualEntrySheet(context),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            iconSize: 22,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
    );
  }
}

/// Тайлы «Тренировки» и «Итоги недели».
class _WorkoutsTile extends ConsumerWidget {
  const _WorkoutsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = ref.watch(workoutsProvider(7)).value?.length;
    final cloudMode = ref.watch(cloudModeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.local_fire_department_rounded,
                    color: theme.colorScheme.tertiary, size: 22),
              ),
              title: const Text('Активность'),
              subtitle: const Text('Движение и энергия за сегодня'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/activity'),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.fitness_center_rounded,
                    color: theme.colorScheme.primary, size: 22),
              ),
              title: const Text('Тренировки'),
              subtitle: Text(count == null ? 'За неделю' : 'За неделю: $count'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/workouts'),
            ),
          ),
          if (cloudMode)
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.calendar_month_rounded,
                      color: theme.colorScheme.tertiary, size: 22),
                ),
                title: const Text('Итоги недели'),
                subtitle: const Text('Сравнение с прошлой неделей'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/weekly'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Индикатор источника данных и статуса синхронизации.
class _SyncChip extends ConsumerWidget {
  const _SyncChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cloudMode = ref.watch(cloudModeProvider);

    if (!cloudMode) {
      return _chip(theme, Icons.smartphone_rounded, 'Локально (на устройстве)',
          theme.colorScheme.outline);
    }

    final status = ref.watch(syncControllerProvider);
    return switch (status.phase) {
      SyncPhase.syncing =>
        _chip(theme, null, 'Синхронизация…', theme.colorScheme.primary,
            spinner: true),
      SyncPhase.synced => _chip(
          theme,
          Icons.cloud_done_rounded,
          'Облако · обновлено ${DateFormat.Hm().format(status.at!)}',
          theme.colorScheme.primary),
      SyncPhase.error => _chip(theme, Icons.cloud_off_rounded,
          'Не удалось синхронизировать', theme.colorScheme.error),
      SyncPhase.idle =>
        _chip(theme, Icons.cloud_rounded, 'Облако', theme.colorScheme.primary),
    };
  }

  Widget _chip(ThemeData theme, IconData? icon, String label, Color color,
      {bool spinner = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner)
            SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: color))
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Чип «кольцо подключено» — показывается, когда идёт живой поток с кольца.
class _RingChip extends ConsumerWidget {
  const _RingChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ringConnectionProvider).value;
    if (state != RingConnState.connected) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.album_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text('Кольцо · live',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({required this.requesting, required this.onRequest});

  final bool requesting;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.health_and_safety_rounded,
                  size: 48, color: theme.colorScheme.onPrimaryContainer),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text('Подключите данные здоровья',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'Разрешите доступ к показателям, чтобы видеть их здесь. '
              'Данные остаются только на устройстве.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: requesting ? null : onRequest,
                child: requesting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Разрешить доступ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.icon, this.action});

  final String text;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
            ],
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
