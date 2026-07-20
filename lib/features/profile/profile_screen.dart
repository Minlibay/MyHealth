import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_controller.dart';
import '../../data/user_profile.dart';

/// Профиль: физические параметры и персональные цели.
/// Параметры отправляются в кольцо (точность калорий) и на сервер
/// (зоны пульса от возраста, цели в скорах).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _gender;
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _stepsGoal = TextEditingController();
  final _waterGoal = TextEditingController();
  final _sleepGoal = TextEditingController();
  final _kcalGoal = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _age, _height, _weight, _stepsGoal, _waterGoal, _sleepGoal, _kcalGoal,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(UserProfile p) {
    if (_loaded) return;
    _loaded = true;
    _gender = p.gender;
    _age.text = p.age?.toString() ?? '';
    _height.text = p.heightCm?.toStringAsFixed(0) ?? '';
    _weight.text = p.weightKg?.toStringAsFixed(0) ?? '';
    _stepsGoal.text = p.stepsGoal?.toString() ?? '';
    _waterGoal.text = p.waterGoalLiters?.toStringAsFixed(1) ?? '';
    _sleepGoal.text = p.sleepGoalHours?.toStringAsFixed(1) ?? '';
    _kcalGoal.text = p.kcalGoal?.toString() ?? '';
  }

  double? _d(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.'));
  int? _i(TextEditingController c) => int.tryParse(c.text);

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileControllerProvider.notifier).save(UserProfile(
            gender: _gender,
            age: _i(_age),
            heightCm: _d(_height),
            weightKg: _d(_weight),
            stepsGoal: _i(_stepsGoal),
            waterGoalLiters: _d(_waterGoal),
            sleepGoalHours: _d(_sleepGoal),
            kcalGoal: _i(_kcalGoal),
          ));
      messenger.showSnackBar(
          const SnackBar(content: Text('Профиль сохранён.')));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, String suffix,
      {bool decimal = false}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileControllerProvider);
    profile.whenData(_fill);

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: profile.isLoading && !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text('О вас',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 4),
                Text(
                  'Возраст задаёт зоны пульса (220 − возраст), рост и вес '
                  'записываются в кольцо для точного расчёта калорий.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'male', label: Text('Мужской')),
                    ButtonSegment(value: 'female', label: Text('Женский')),
                  ],
                  selected: {?_gender},
                  emptySelectionAllowed: true,
                  onSelectionChanged: (s) =>
                      setState(() => _gender = s.isEmpty ? null : s.first),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(_age, 'Возраст', 'лет')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_height, 'Рост', 'см')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_weight, 'Вес', 'кг')),
                ]),
                const SizedBox(height: 24),
                Text('Цели',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 4),
                Text(
                  'Используются в оценках сна, питания и активности. '
                  'Пустое поле — цель по умолчанию.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(_stepsGoal, 'Шаги в день', 'шагов')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _field(_sleepGoal, 'Сон', 'ч', decimal: true)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _field(_waterGoal, 'Вода', 'л', decimal: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_kcalGoal, 'Калории', 'ккал')),
                ]),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Сохранить'),
                ),
              ],
            ),
    );
  }
}
