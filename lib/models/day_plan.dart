class DayPlan {
  final DateTime date;
  final Map<String, List<String>> slotMeals; // slotId -> list of mealIds
  final List<String> clearedIngredients;

  DayPlan({
    required this.date,
    required this.slotMeals,
    this.clearedIngredients = const [],
  });

  DayPlan copyWith({
    DateTime? date,
    Map<String, List<String>>? slotMeals,
    List<String>? clearedIngredients,
  }) {
    return DayPlan(
      date: date ?? this.date,
      slotMeals: slotMeals ?? this.slotMeals,
      clearedIngredients: clearedIngredients ?? this.clearedIngredients,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'slotMeals': slotMeals,
      'clearedIngredients': clearedIngredients,
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

    return DayPlan(
      date: date,
      slotMeals: slotMeals,
      clearedIngredients: cleared,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan.fromMap(json);
}
