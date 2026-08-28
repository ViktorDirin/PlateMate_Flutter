class DayPlan {
  final DateTime date;
  final Map<String, List<String>> slotMeals; // slotId -> list of mealIds
  final List<String> clearedIngredients;
  final Map<String, bool> slotCompleted; // slotId -> isCompleted
  final Map<String, DateTime?> slotCompletedAt; // slotId -> completedAt

  DayPlan({
    required this.date,
    required this.slotMeals,
    this.clearedIngredients = const [],
    this.slotCompleted = const {},
    this.slotCompletedAt = const {},
  });

  DayPlan copyWith({
    DateTime? date,
    Map<String, List<String>>? slotMeals,
    List<String>? clearedIngredients,
    Map<String, bool>? slotCompleted,
    Map<String, DateTime?>? slotCompletedAt,
  }) {
    return DayPlan(
      date: date ?? this.date,
      slotMeals: slotMeals ?? this.slotMeals,
      clearedIngredients: clearedIngredients ?? this.clearedIngredients,
      slotCompleted: slotCompleted ?? this.slotCompleted,
      slotCompletedAt: slotCompletedAt ?? this.slotCompletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, String?> rawCompletedAt = {};
    slotCompletedAt.forEach((key, value) {
      rawCompletedAt[key] = value?.toIso8601String();
    });

    return {
      'date': date.toIso8601String(),
      'slotMeals': slotMeals,
      'clearedIngredients': clearedIngredients,
      'slotCompleted': slotCompleted,
      'slotCompletedAt': rawCompletedAt,
    };
  }

  factory DayPlan.fromMap(Map<String, dynamic> map) {
    final date = DateTime.parse(map['date'] as String);
    final Map<String, List<String>> slotMeals = {};

    if (map['slotMeals'] != null) {
      final rawSlotMeals = map['slotMeals'] as Map<String, dynamic>;
      rawSlotMeals.forEach((key, value) {
        slotMeals[key] = List<String>.from(value as List<dynamic>);
      });
    } else {
      // Migrate from old hardcoded layout structure
      if (map['breakfastMealId'] != null) {
        slotMeals['00000000-0000-0000-0000-000000000001'] = [map['breakfastMealId'] as String];
      }
      if (map['lunchMealId'] != null) {
        slotMeals['00000000-0000-0000-0000-000000000002'] = [map['lunchMealId'] as String];
      }
      if (map['dinnerMealId'] != null) {
        slotMeals['00000000-0000-0000-0000-000000000003'] = [map['dinnerMealId'] as String];
      }
      if (map['snackMealIds'] != null) {
        slotMeals['00000000-0000-0000-0000-000000000004'] = List<String>.from(map['snackMealIds'] as List<dynamic>);
      }
    }

    final cleared = List<String>.from(map['clearedIngredients'] ?? const []);

    final Map<String, bool> slotCompleted = {};
    if (map['slotCompleted'] != null) {
      final rawCompleted = map['slotCompleted'] as Map<String, dynamic>;
      rawCompleted.forEach((key, value) {
        slotCompleted[key] = value as bool;
      });
    }

    final Map<String, DateTime?> slotCompletedAt = {};
    if (map['slotCompletedAt'] != null) {
      final rawCompletedAt = map['slotCompletedAt'] as Map<String, dynamic>;
      rawCompletedAt.forEach((key, value) {
        slotCompletedAt[key] = value != null ? DateTime.parse(value as String) : null;
      });
    }

    return DayPlan(
      date: date,
      slotMeals: slotMeals,
      clearedIngredients: cleared,
      slotCompleted: slotCompleted,
      slotCompletedAt: slotCompletedAt,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan.fromMap(json);
}
