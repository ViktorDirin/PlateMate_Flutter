import 'package:flutter_test/flutter_test.dart';
import 'package:platemate/ui/widgets/time_input_formatter.dart';
import 'package:platemate/models/meal.dart';
import 'package:platemate/models/day_plan.dart';
import 'package:platemate/models/meal_slot_config.dart';
import 'package:platemate/blocs/diet_bloc.dart';

void main() {
  group('TimeInputFormatter Normalization Tests', () {
    test('Should normalize single digits to hours', () {
      expect(TimeInputFormatter.normalizeTime('9'), '09:00');
    });

    test('Should normalize two digits to hours', () {
      expect(TimeInputFormatter.normalizeTime('12'), '12:00');
      expect(TimeInputFormatter.normalizeTime('25'), '23:00'); // Clamped
    });

    test('Should normalize three digits (HHMM)', () {
      expect(TimeInputFormatter.normalizeTime('930'), '09:30');
      expect(TimeInputFormatter.normalizeTime('815'), '08:15');
    });

    test('Should normalize four digits (HHMM)', () {
      expect(TimeInputFormatter.normalizeTime('1915'), '19:15');
      expect(TimeInputFormatter.normalizeTime('2359'), '23:59');
      expect(TimeInputFormatter.normalizeTime('2570'), '23:59'); // Clamped
    });
  });

  group('Meal Model Tests', () {
    test('Should serialize and deserialize correctly', () {
      final meal = Meal(
        id: 'test-meal-id',
        name: 'Spaghetti Carbonara',
        category: 'Dinner',
        ingredients: ['Pasta', 'Egg', 'Pecorino', 'Guanciale'],
      );
      final map = meal.toMap();
      
      expect(map['id'], 'test-meal-id');
      expect(map['name'], 'Spaghetti Carbonara');
      expect(map['category'], 'Dinner');
      expect(map['ingredients'], ['Pasta', 'Egg', 'Pecorino', 'Guanciale']);

      final fromMap = Meal.fromMap(map);
      expect(fromMap.id, 'test-meal-id');
      expect(fromMap.name, 'Spaghetti Carbonara');
      expect(fromMap.category, 'Dinner');
      expect(fromMap.ingredients, ['Pasta', 'Egg', 'Pecorino', 'Guanciale']);
    });
  });

  group('DayPlan Model Tests', () {
    test('Should serialize and deserialize correctly with slot mapping and clearedIngredients', () {
      final date = DateTime(2026, 8, 26);
      final plan = DayPlan(
        date: date,
        slotMeals: {
          'breakfast': ['b-id'],
          'lunch': ['l-id'],
          'dinner': ['d-id'],
          'snacks': ['s1-id', 's2-id'],
        },
        clearedIngredients: ['eggs', 'milk'],
      );
      final map = plan.toMap();

      expect(map['date'], date.toIso8601String());
      expect(map['slotMeals']['breakfast'], ['b-id']);
      expect(map['slotMeals']['snacks'], ['s1-id', 's2-id']);
      expect(map['clearedIngredients'], ['eggs', 'milk']);

      final fromMap = DayPlan.fromMap(map);
      expect(fromMap.date, date);
      expect(fromMap.slotMeals['breakfast'], ['b-id']);
      expect(fromMap.slotMeals['snacks'], ['s1-id', 's2-id']);
      expect(fromMap.clearedIngredients, ['eggs', 'milk']);
    });

    test('Should parse older database models and migrate format cleanly', () {
      final date = DateTime(2026, 8, 26);
      final oldMap = {
        'date': date.toIso8601String(),
        'breakfastMealId': 'old-b-id',
        'lunchMealId': 'old-l-id',
        'dinnerMealId': 'old-d-id',
        'snackMealIds': ['old-s1-id', 'old-s2-id'],
      };

      final plan = DayPlan.fromMap(oldMap);
      expect(plan.date, date);
      expect(plan.slotMeals['00000000-0000-0000-0000-000000000001'], ['old-b-id']);
      expect(plan.slotMeals['00000000-0000-0000-0000-000000000002'], ['old-l-id']);
      expect(plan.slotMeals['00000000-0000-0000-0000-000000000003'], ['old-d-id']);
      expect(plan.slotMeals['00000000-0000-0000-0000-000000000004'], ['old-s1-id', 'old-s2-id']);
      expect(plan.clearedIngredients, isEmpty);
    });
  });

  group('MealSlotConfig Model Tests', () {
    test('Should serialize and deserialize slot configuration', () {
      final config = MealSlotConfig(
        id: 'pre_workout',
        name: 'Pre-workout Meal',
        orderIndex: 4,
        isEnabled: true,
      );

      final map = config.toMap();
      expect(map['id'], 'pre_workout');
      expect(map['name'], 'Pre-workout Meal');
      expect(map['orderIndex'], 4);
      expect(map['isEnabled'], true);

      final fromMap = MealSlotConfig.fromMap(map);
      expect(fromMap.id, 'pre_workout');
      expect(fromMap.name, 'Pre-workout Meal');
      expect(fromMap.orderIndex, 4);
      expect(fromMap.isEnabled, true);
    });
  });

  group('DietState Serialization Tests', () {
    test('Should serialize and deserialize DietState with grocery items and slots', () {
      final state = DietState(
        mealsLibrary: [],
        dayPlans: [],
        crossedIngredients: ['eggs', 'milk'],
        manualGroceryItems: ['Apples', 'Banana'],
        mealSlots: [
          MealSlotConfig(id: 'br', name: 'Brunch', orderIndex: 0),
        ],
      );

      final json = state.toJson();
      expect(json['crossedIngredients'], ['eggs', 'milk']);
      expect(json['manualGroceryItems'], ['Apples', 'Banana']);
      expect(json['mealSlots'][0]['id'], 'br');

      final fromJson = DietState.fromJson(json);
      expect(fromJson.crossedIngredients, ['eggs', 'milk']);
      expect(fromJson.manualGroceryItems, ['Apples', 'Banana']);
      expect(fromJson.mealSlots[0].id, 'br');
    });
  });
}
