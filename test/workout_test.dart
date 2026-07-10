import 'package:flutter_test/flutter_test.dart';
import 'package:myhealth/data/workout.dart';

void main() {
  Workout w(String type) => Workout(
        activityType: type,
        start: DateTime(2026, 7, 10, 8),
        end: DateTime(2026, 7, 10, 8, 45),
      );

  test('известные типы активности переводятся на русский', () {
    expect(w('RUNNING').title, 'Бег');
    expect(w('YOGA').title, 'Йога');
    expect(w('HIGH_INTENSITY_INTERVAL_TRAINING').title, 'HIIT');
  });

  test('незнакомый тип облагораживается из сырого имени', () {
    expect(w('ROCK_CLIMBING_INDOOR').title, 'Rock climbing indoor');
  });

  test('длительность считается из start/end', () {
    expect(w('RUNNING').duration.inMinutes, 45);
  });
}
