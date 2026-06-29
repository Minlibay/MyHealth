import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health_metric.dart';
import '../../providers.dart';

/// Первый экран: информированное согласие на обработку данных о здоровье.
/// Требование GDPR — пользователь явно соглашается до доступа к данным.
class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary,
                            Color.lerp(theme.colorScheme.primary, Colors.black,
                                0.2)!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Icon(Icons.health_and_safety_rounded,
                          size: 46, color: Colors.white),
                    ),
                  )
                      .animate()
                      .scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  Text('Ваши данные остаются у вас',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                    'MyHealth считывает показатели из системного хранилища '
                    'здоровья (Apple Health / Google Health Connect) и '
                    'показывает их вам. Данные хранятся только на этом '
                    'устройстве, никуда не передаются и не покидают телефон.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      child: Column(
                        children: [
                          for (final m in HealthMetric.values)
                            ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: m.color.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(m.icon, color: m.color, size: 20),
                              ),
                              title: Text(m.title),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 18, color: theme.colorScheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Согласие можно отозвать в настройках — локальные '
                          'данные будут удалены.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      ref.read(consentControllerProvider.notifier).grant(),
                  child: const Text('Принимаю'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
