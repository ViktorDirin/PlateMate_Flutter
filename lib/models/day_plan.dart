class DayPlan {
  final DateTime date;
  final Map<String, List<String>> slotMeals; // slotId -> list of mealIds
  final List<String> clearedIngredients;
  final Map<String, bool> slotCompleted; // slotId -> isCompleted
  final Map<String, DateTime?> slotCompletedAt; // slotId -> completedAt
  final Map<String, bool> slotIsActual; // slotId -> isActual
  final Map<String, String?> slotActualMealName; // slotId -> actualMealName
  final Map<String, double?> slotCalories; // slotId -> calories
  final Map<String, double?> slotProtein; // slotId -> protein
  final Map<String, double?> slotFats; // slotId -> fats
  final Map<String, double?> slotCarbs; // slotId -> carbs
  final Map<String, double?> slotFiber; // slotId -> fiber
  final Map<String, String?> slotUserNote; // slotId -> userNote
  final Map<String, dynamic> slotAiBreakdown; // slotId -> aiBreakdown

  DayPlan({
    required this.date,
    required this.slotMeals,
    this.clearedIngredients = const [],
    this.slotCompleted = const {},
    this.slotCompletedAt = const {},
    this.slotIsActual = const {},
    this.slotActualMealName = const {},
    this.slotCalories = const {},
    this.slotProtein = const {},
    this.slotFats = const {},
    this.slotCarbs = const {},
    this.slotFiber = const {},
    this.slotUserNote = const {},
    this.slotAiBreakdown = const {},
  });

  DayPlan copyWith({
    DateTime? date,
    Map<String, List<String>>? slotMeals,
    List<String>? clearedIngredients,
    Map<String, bool>? slotCompleted,
    Map<String, DateTime?>? slotCompletedAt,
    Map<String, bool>? slotIsActual,
    Map<String, String?>? slotActualMealName,
    Map<String, double?>? slotCalories,
    Map<String, double?>? slotProtein,
    Map<String, double?>? slotFats,
    Map<String, double?>? slotCarbs,
    Map<String, double?>? slotFiber,
    Map<String, String?>? slotUserNote,
    Map<String, dynamic>? slotAiBreakdown,
  }) {
    return DayPlan(
      date: date ?? this.date,
      slotMeals: slotMeals ?? this.slotMeals,
      clearedIngredients: clearedIngredients ?? this.clearedIngredients,
      slotCompleted: slotCompleted ?? this.slotCompleted,
      slotCompletedAt: slotCompletedAt ?? this.slotCompletedAt,
      slotIsActual: slotIsActual ?? this.slotIsActual,
      slotActualMealName: slotActualMealName ?? this.slotActualMealName,
      slotCalories: slotCalories ?? this.slotCalories,
      slotProtein: slotProtein ?? this.slotProtein,
      slotFats: slotFats ?? this.slotFats,
      slotCarbs: slotCarbs ?? this.slotCarbs,
      slotFiber: slotFiber ?? this.slotFiber,
      slotUserNote: slotUserNote ?? this.slotUserNote,
      slotAiBreakdown: slotAiBreakdown ?? this.slotAiBreakdown,
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
      'slotIsActual': slotIsActual,
      'slotActualMealName': slotActualMealName,
      'slotCalories': slotCalories,
      'slotProtein': slotProtein,
      'slotFats': slotFats,
      'slotCarbs': slotCarbs,
      'slotFiber': slotFiber,
      'slotUserNote': slotUserNote,
      'slotAiBreakdown': slotAiBreakdown,
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

    final Map<String, bool> slotIsActual = {};
    if (map['slotIsActual'] != null) {
      final rawIsActual = map['slotIsActual'] as Map<String, dynamic>;
      rawIsActual.forEach((key, value) {
        slotIsActual[key] = value as bool;
      });
    }

    final Map<String, String?> slotActualMealName = {};
    if (map['slotActualMealName'] != null) {
      final rawActualName = map['slotActualMealName'] as Map<String, dynamic>;
      rawActualName.forEach((key, value) {
        slotActualMealName[key] = value as String?;
      });
    }

    final Map<String, double?> slotCalories = {};
    if (map['slotCalories'] != null) {
      final raw = map['slotCalories'] as Map<String, dynamic>;
      raw.forEach((key, value) {
        slotCalories[key] = (value as num?)?.toDouble();
      });
    }

    final Map<String, double?> slotProtein = {};
    if (map['slotProtein'] != null) {
      final raw = map['slotProtein'] as Map<String, dynamic>;
      raw.forEach((key, value) {
        slotProtein[key] = (value as num?)?.toDouble();
      });
    }

    final Map<String, double?> slotFats = {};
    if (map['slotFats'] != null) {
      final raw = map['slotFats'] as Map<String, dynamic>;
      raw.forEach((key, value) {
        slotFats[key] = (value as num?)?.toDouble();
      });
    }

    final Map<String, double?> slotCarbs = {};
    if (map['slotCarbs'] != null) {
      final raw = map['slotCarbs'] as Map<String, dynamic>;
      raw.forEach((key, value) {
        slotCarbs[key] = (value as num?)?.toDouble();
      });
    }

    final Map<String, double?> slotFiber = {};
    if (map['slotFiber'] != null) {
      final raw = map['slotFiber'] as Map<String, dynamic>;
      raw.forEach((key, value) {
        slotFiber[key] = (value as num?)?.toDouble();
      });
    }

    final Map<String, String?> slotUserNote = {};
    if (map['slotUserNote'] != null) {
      final raw = map['slotUserNote'] as Map<String, dynamic>;
      raw.forEach((key, value) {
        slotUserNote[key] = value as String?;
      });
    }

    final Map<String, dynamic> slotAiBreakdown = {};
    if (map['slotAiBreakdown'] != null) {
      final raw = map['slotAiBreakdown'] as Map<String, dynamic>;
      raw.forEach((key, value) {
        slotAiBreakdown[key] = value;
      });
    }

    return DayPlan(
      date: date,
      slotMeals: slotMeals,
      clearedIngredients: cleared,
      slotCompleted: slotCompleted,
      slotCompletedAt: slotCompletedAt,
      slotIsActual: slotIsActual,
      slotActualMealName: slotActualMealName,
      slotCalories: slotCalories,
      slotProtein: slotProtein,
      slotFats: slotFats,
      slotCarbs: slotCarbs,
      slotFiber: slotFiber,
      slotUserNote: slotUserNote,
      slotAiBreakdown: slotAiBreakdown,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan.fromMap(json);
}
