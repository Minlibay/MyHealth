import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/api/tags_api.dart';
import '../../data/auth/auth_controller.dart';
import '../../providers.dart';

final tagsApiProvider =
    Provider<TagsApi>((ref) => TagsApi(ref.watch(apiClientProvider)));

/// Теги за последнюю неделю (для отображения в шите).
final recentTagsProvider = FutureProvider<List<TagEntry>>((ref) async {
  if (!ref.watch(cloudModeProvider)) return const [];
  return ref.watch(tagsApiProvider).fetch(days: 7);
});

/// Стандартные теги: ключ на сервере + подпись и иконка.
const _tags = [
  (key: 'coffee', label: 'Кофе', icon: Icons.coffee_rounded),
  (key: 'alcohol', label: 'Алкоголь', icon: Icons.wine_bar_rounded),
  (key: 'late_meal', label: 'Поздняя еда', icon: Icons.fastfood_rounded),
  (key: 'stress', label: 'Стресс', icon: Icons.bolt_rounded),
  (key: 'sick', label: 'Болею', icon: Icons.sick_rounded),
  (key: 'travel', label: 'Поездка', icon: Icons.flight_rounded),
  (key: 'late_workout', label: 'Трен. вечером', icon: Icons.fitness_center_rounded),
  (key: 'meditation', label: 'Медитация', icon: Icons.self_improvement_rounded),
];

String tagLabel(String key) {
  for (final t in _tags) {
    if (t.key == key) return t.label;
  }
  return key;
}

/// Быстрая отметка «что было сегодня» — сырьё для будущих корреляций
/// («после алкоголя ваш HRV в среднем ниже»).
Future<void> showTagSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    builder: (_) => const _TagSheet(),
  );
}

class _TagSheet extends ConsumerWidget {
  const _TagSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cloudMode = ref.watch(cloudModeProvider);
    final recent = ref.watch(recentTagsProvider).value ?? const <TagEntry>[];

    Future<void> add(String key) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(tagsApiProvider).add(key);
        ref.invalidate(recentTagsProvider);
        messenger.showSnackBar(
            SnackBar(content: Text('Отмечено: ${tagLabel(key)}')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Журнал', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            cloudMode
                ? 'Отметьте события дня — со временем появятся корреляции '
                    'с вашим сном и восстановлением.'
                : 'Войдите в аккаунт, чтобы вести журнал.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _tags)
                ActionChip(
                  avatar: Icon(t.icon, size: 18),
                  label: Text(t.label),
                  onPressed: cloudMode ? () => add(t.key) : null,
                ),
            ],
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Последние отметки',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            for (final t in recent.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(tagLabel(t.tag),
                            style: theme.textTheme.bodyMedium)),
                    Text(
                      DateFormat('d MMM, HH:mm', 'ru').format(t.at),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
