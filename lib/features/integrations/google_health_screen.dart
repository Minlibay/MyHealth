import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/api/google_health_api.dart';
import '../../data/google_health/google_health_controller.dart';
import '../../data/google_health/google_health_oauth.dart';
import '../../providers.dart';

/// Экран подключения Google Health (данные Fitbit/Google из облака).
class GoogleHealthScreen extends ConsumerStatefulWidget {
  const GoogleHealthScreen({super.key});

  @override
  ConsumerState<GoogleHealthScreen> createState() => _GoogleHealthScreenState();
}

class _GoogleHealthScreenState extends ConsumerState<GoogleHealthScreen> {
  bool _busy = false;

  Future<void> _connect() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await ref.read(googleHealthControllerProvider).connect();
      messenger.showSnackBar(
          SnackBar(content: Text('Подключено. Загружено записей: $n')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await ref.read(googleHealthControllerProvider).sync();
      messenger.showSnackBar(
          SnackBar(content: Text('Синхронизация: загружено записей $n')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(googleHealthControllerProvider).disconnect();
      messenger.showSnackBar(const SnackBar(content: Text('Отключено.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cloudMode = ref.watch(cloudModeProvider);
    final status = ref.watch(googleHealthStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Google Health / Fitbit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Подключите аккаунт Google Health (Fitbit), чтобы подтягивать '
                'данные напрямую из облака Google — без Apple Health. '
                'Синхронизация идёт через наш сервер, поэтому нужен вход в '
                'аккаунт MyHealth.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!googleHealthSupported)
            const _Note(
              'На этой платформе вход в Google Health пока недоступен '
              '(готов iOS; Android добавим после регистрации Android-клиента).',
            )
          else if (!cloudMode)
            const _Note(
              'Сначала войдите в аккаунт MyHealth (раздел «Облако» в настройках) '
              '— данные Google синхронизируются через сервер.',
            )
          else
            status.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Note('Ошибка: $e'),
              data: (s) => s.connected
                  ? _ConnectedCard(
                      status: s,
                      busy: _busy,
                      onSync: _sync,
                      onDisconnect: _disconnect)
                  : FilledButton.icon(
                      onPressed: _busy ? null : _connect,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.link_rounded),
                      label: const Text('Подключить Google Health'),
                    ),
            ),
        ],
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({
    required this.status,
    required this.busy,
    required this.onSync,
    required this.onDisconnect,
  });

  final GoogleHealthStatus status;
  final bool busy;
  final VoidCallback onSync;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: Icon(Icons.check_circle_rounded,
                color: theme.colorScheme.primary),
            title: const Text('Подключено'),
            subtitle: Text(status.lastSyncAt == null
                ? 'Данные загружаются…'
                : 'Обновлено ${DateFormat('d MMM, HH:mm', 'ru').format(status.lastSyncAt!)}'),
          ),
        ),
        if (status.lastError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(status.lastError!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: busy ? null : onSync,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync_rounded),
          label: const Text('Синхронизировать'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : onDisconnect,
          icon: const Icon(Icons.link_off_rounded),
          label: const Text('Отключить'),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}
