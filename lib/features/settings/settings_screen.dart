import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/auth_controller.dart';
import '../../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SectionTitle('Облако'),
          Card(
            child: auth.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text('Ошибка: $e'),
              ),
              data: (session) => session == null
                  ? ListTile(
                      leading: Icon(Icons.cloud_outlined,
                          color: theme.colorScheme.primary),
                      title: const Text('Войти или зарегистрироваться'),
                      subtitle: const Text(
                          'Синхронизируйте показатели с сервером.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/login'),
                    )
                  : Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.cloud_done_outlined,
                              color: theme.colorScheme.primary),
                          title: Text(session.email),
                          subtitle: const Text('Вы вошли в аккаунт'),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.sync),
                          title: const Text('Синхронизировать сейчас'),
                          onTap: () => _sync(context, ref),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Выйти из аккаунта'),
                          onTap: () =>
                              ref.read(authControllerProvider.notifier).signOut(),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Устройства'),
          Card(
            child: ListTile(
              leading: Icon(Icons.bluetooth_rounded,
                  color: theme.colorScheme.primary),
              title: const Text('Кольцо JCRing X3'),
              subtitle: const Text('Подключение по Bluetooth и живые показатели'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/ring'),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Внешний вид'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('Тема', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded),
                          label: Text('Авто')),
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded),
                          label: Text('Светлая')),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded),
                          label: Text('Тёмная')),
                    ],
                    selected: {mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).set(s.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Данные и приватность'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.shield_outlined,
                      color: theme.colorScheme.primary),
                  title: const Text('О данных'),
                  subtitle: const Text(
                    'Локальные показатели хранятся на устройстве. На сервер '
                    'отправляются только при синхронизации после входа.',
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded,
                      color: theme.colorScheme.error),
                  title: Text('Отозвать согласие и удалить данные',
                      style: TextStyle(color: theme.colorScheme.error)),
                  subtitle: const Text(
                    'Доступ к хранилищу здоровья будет отозван, локальные '
                    'данные удалены.',
                  ),
                  onTap: () => _confirmRevoke(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(syncControllerProvider.notifier).syncNow();
    final st = ref.read(syncControllerProvider);
    final text = st.phase == SyncPhase.error
        ? 'Ошибка: ${st.message}'
        : (st.inserted ?? 0) > 0
            ? 'Синхронизировано новых записей: ${st.inserted}'
            : 'Уже всё синхронизировано';
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _confirmRevoke(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отозвать согласие?'),
        content: const Text(
          'Приложение перестанет читать данные о здоровье, локальные данные '
          'будут удалены.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Отозвать')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(deviceRepositoryProvider).revokePermissions();
    } catch (_) {}
    await ref.read(consentControllerProvider.notifier).revoke();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.outline,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
