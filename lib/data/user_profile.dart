/// Профиль пользователя: физические параметры (зоны пульса, калории
/// кольца) и персональные цели (скоры на бэкенде).
class UserProfile {
  const UserProfile({
    this.gender,
    this.age,
    this.heightCm,
    this.weightKg,
    this.stepsGoal,
    this.waterGoalLiters,
    this.sleepGoalHours,
    this.kcalGoal,
  });

  /// 'male' | 'female'.
  final String? gender;
  final int? age;
  final double? heightCm;
  final double? weightKg;

  final int? stepsGoal;
  final double? waterGoalLiters;
  final double? sleepGoalHours;
  final int? kcalGoal;

  /// Достаточно ли данных для записи в кольцо (SetPersonalInfo).
  bool get isCompleteForRing =>
      gender != null && age != null && heightCm != null && weightKg != null;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        gender: json['gender'] as String?,
        age: (json['age'] as num?)?.toInt(),
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        stepsGoal: (json['stepsGoal'] as num?)?.toInt(),
        waterGoalLiters: (json['waterGoalLiters'] as num?)?.toDouble(),
        sleepGoalHours: (json['sleepGoalHours'] as num?)?.toDouble(),
        kcalGoal: (json['kcalGoal'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'stepsGoal': stepsGoal,
        'waterGoalLiters': waterGoalLiters,
        'sleepGoalHours': sleepGoalHours,
        'kcalGoal': kcalGoal,
      };
}
