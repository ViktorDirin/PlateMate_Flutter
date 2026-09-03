import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:platemate/blocs/diet_bloc.dart';
import 'package:platemate/models/day_plan.dart';
import 'package:platemate/services/food_analysis_service.dart';
import 'package:platemate/ui/widgets/meal_nutrition_breakdown_dialog.dart';

class MockStorage extends Storage {
  final Map<String, dynamic> _storage = {};

  @override
  dynamic read(String key) => _storage[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HydratedBloc.storage = MockStorage();
  });

  tearDownAll(() async {
    await HydratedBloc.storage.clear();
  });

  group('FoodAnalysisResult & FoodAnalysisItem Serialization', () {
    test('parses from valid Edge function JSON payload', () {
      final json = {
        'meal_name': 'Grilled Salmon Salad',
        'calories': 520,
        'protein': 42.5,
        'fats': 24.0,
        'carbs': 18.2,
        'fiber': 6.5,
        'items': [
          {
            'name': 'Salmon Fillet',
            'weight_g': 180,
            'calories': 360,
            'protein': 36.0,
            'fats': 22.0,
            'carbs': 0.0,
          },
          {
            'name': 'Mixed Greens',
            'portion': '1 cup',
            'calories': 20,
            'protein': 1.5,
            'fats': 0.2,
            'carbs': 3.5,
          }
        ]
      };

      final result = FoodAnalysisResult.fromMap(json);

      expect(result.mealName, 'Grilled Salmon Salad');
      expect(result.calories, 520.0);
      expect(result.protein, 42.5);
      expect(result.fats, 24.0);
      expect(result.carbs, 18.2);
      expect(result.fiber, 6.5);
      expect(result.items.length, 2);
      expect(result.items.first.name, 'Salmon Fillet');
      expect(result.items.first.weight, '180g');
      expect(result.items.first.calories, 360.0);
      expect(result.items[1].weight, '1 cup');
    });
  });

  group('DayPlan Actual Nutrition Serialization', () {
    test('toMap and fromMap retain factual fields accurately', () {
      final now = DateTime.now();
      final dayPlan = DayPlan(
        date: DateTime(2026, 9, 2),
        slotMeals: {
          'slot-1': ['meal-101']
        },
        slotCompleted: {'slot-1': true},
        slotCompletedAt: {'slot-1': now},
        slotIsActual: {'slot-1': true},
        slotActualMealName: {'slot-1': 'Chicken Rice Bowl'},
        slotCalories: {'slot-1': 650.0},
        slotProtein: {'slot-1': 48.0},
        slotFats: {'slot-1': 15.0},
        slotCarbs: {'slot-1': 75.0},
        slotFiber: {'slot-1': 5.0},
        slotUserNote: {'slot-1': 'Extra hot sauce'},
        slotAiBreakdown: {
          'slot-1': [
            {'name': 'Chicken Breast', 'calories': 300},
            {'name': 'White Rice', 'calories': 350}
          ]
        },
      );

      final map = dayPlan.toMap();
      final reconstituted = DayPlan.fromMap(map);

      expect(reconstituted.slotIsActual['slot-1'], true);
      expect(reconstituted.slotActualMealName['slot-1'], 'Chicken Rice Bowl');
      expect(reconstituted.slotCalories['slot-1'], 650.0);
      expect(reconstituted.slotProtein['slot-1'], 48.0);
      expect(reconstituted.slotFats['slot-1'], 15.0);
      expect(reconstituted.slotCarbs['slot-1'], 75.0);
      expect(reconstituted.slotFiber['slot-1'], 5.0);
      expect(reconstituted.slotUserNote['slot-1'], 'Extra hot sauce');
      expect(reconstituted.slotCompleted['slot-1'], true);
    });
  });

  group('DietBloc LogActualMeal & ClearActualMeal Events', () {
    test('LogActualMeal sets is_actual and is_completed with nutrition details', () async {
      final bloc = DietBloc();
      final testDate = DateTime(2026, 9, 2);
      const slotId = 'slot-lunch';

      bloc.add(
        LogActualMeal(
          date: testDate,
          slotId: slotId,
          actualMealName: 'Beef Steak & Asparagus',
          calories: 580.0,
          protein: 52.0,
          fats: 32.0,
          carbs: 8.0,
          fiber: 3.5,
          userNote: 'Cooked with butter',
          aiBreakdown: [{'name': 'Ribeye Steak', 'weight': '200g'}],
        ),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final plan = bloc.state.dayPlans.firstWhere((p) => p.date.day == testDate.day);
      expect(plan.slotIsActual[slotId], true);
      expect(plan.slotCompleted[slotId], true);
      expect(plan.slotActualMealName[slotId], 'Beef Steak & Asparagus');
      expect(plan.slotCalories[slotId], 580.0);
      expect(plan.slotProtein[slotId], 52.0);
      expect(plan.slotFats[slotId], 32.0);
      expect(plan.slotCarbs[slotId], 8.0);
      expect(plan.slotFiber[slotId], 3.5);
      expect(plan.slotUserNote[slotId], 'Cooked with butter');

      // Now clear actual meal
      bloc.add(ClearActualMeal(date: testDate, slotId: slotId));
      await Future.delayed(const Duration(milliseconds: 100));

      final clearedPlan = bloc.state.dayPlans.firstWhere((p) => p.date.day == testDate.day);
      expect(clearedPlan.slotIsActual[slotId], isNull);
      expect(clearedPlan.slotActualMealName[slotId], isNull);
      expect(clearedPlan.slotCalories[slotId], isNull);

      await bloc.close();
    });
  });

  group('MealNutritionBreakdownDialog Widget Tests', () {
    testWidgets('renders all nutrition badges, breakdown items, and user note', (WidgetTester tester) async {
      final testDate = DateTime(2026, 9, 2);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealNutritionBreakdownDialog(
              date: testDate,
              slotId: 'slot-1',
              slotName: 'Lunch',
              mealName: 'Salmon Avocado Bowl',
              calories: 540.0,
              protein: 38.0,
              fats: 26.0,
              carbs: 42.0,
              fiber: 7.0,
              userNote: 'With sesame dressing',
              aiBreakdown: [
                {'name': 'Atlantic Salmon', 'weight': '150g', 'calories': 300},
                {'name': 'Avocado Slice', 'weight': '50g', 'calories': 80},
              ],
              completedAt: DateTime(2026, 9, 2, 13, 15),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and titles
      expect(find.text('Meal Nutrition Breakdown'), findsOneWidget);
      expect(find.text('Salmon Avocado Bowl'), findsOneWidget);
      expect(find.textContaining('Lunch'), findsOneWidget);

      // Check macro summary badges
      expect(find.text('540 kcal'), findsOneWidget);
      expect(find.text('38.0g'), findsOneWidget);
      expect(find.text('26.0g'), findsOneWidget);
      expect(find.text('42.0g'), findsOneWidget);
      expect(find.text('7.0g'), findsOneWidget);

      // Check recognized breakdown items
      expect(find.text('Atlantic Salmon'), findsOneWidget);
      expect(find.text('150g'), findsOneWidget);
      expect(find.text('300 kcal'), findsOneWidget);
      expect(find.text('Avocado Slice'), findsOneWidget);

      // Check user note
      expect(find.text('With sesame dressing'), findsOneWidget);

      // Check action buttons & bookmark icon
      expect(find.text('Clear Slot'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Re-analyze'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);
    });
  });
}
