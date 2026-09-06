import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:platemate/blocs/diet_bloc.dart';
import 'package:platemate/main.dart';
import 'package:platemate/models/day_plan.dart';
import 'package:platemate/models/meal.dart';
import 'package:platemate/models/meal_slot_config.dart';
import 'package:platemate/services/food_analysis_service.dart';
import 'package:platemate/services/meal_photo_service.dart';
import 'package:platemate/services/report_export_service.dart';
import 'package:platemate/ui/screens/meals_library_screen.dart';
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

  setUp(() async {
    await HydratedBloc.storage.clear();
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

    test('LocalFoodParser estimates Cyrillic / Russian ingredient description accurately', () {
      final result = LocalFoodParser.parse(
        mealName: 'Фирменный салат с тунцом',
        ingredients: ['банка тунца 130г, 1 огурец, помидор 120г, вареное яйцо, салат айсберг 100г'],
      );

      expect(result.mealName, 'Фирменный салат с тунцом');
      expect(result.calories, greaterThan(200));
      expect(result.protein, greaterThanOrEqualTo(25));
      expect(result.fats, greaterThan(3));
      expect(result.items.length, 5);
    });

    test('LocalFoodParser estimates English multi-ingredient recipe accurately', () {
      final result = LocalFoodParser.parse(
        mealName: 'Chicken and Rice Bowl',
        ingredients: ['Chicken Breast 150g, White Rice 150g, 1 Avocado, Olive Oil 10g'],
      );

      expect(result.calories, greaterThan(400));
      expect(result.protein, greaterThan(30));
      expect(result.items.length, 4);
    });

    test('LocalFoodParser parses unpunctuated conversational speech-to-text dictation with all items', () {
      final speechInput = 'один огурец в 100 г один помидор 100 г а один салатный лист 100 г одно варёное яйцо 50 г одна консервная банка тунца наверное 100 г';
      final result = LocalFoodParser.parse(
        mealName: 'Салат',
        ingredients: [speechInput],
      );

      // Verify all 5 items are recognized and accumulated
      expect(result.items.length, 5);
      expect(result.calories, greaterThan(200));
      expect(result.protein, greaterThan(30));
      expect(result.cleanedDescription, isNotNull);
      expect(result.cleanedDescription, contains('Cucumber'));
      expect(result.cleanedDescription, contains('Tomato'));
      expect(result.cleanedDescription, contains('Salad Greens'));
      expect(result.cleanedDescription, contains('Boiled Egg'));
      expect(result.cleanedDescription, contains('Canned Tuna'));
    });
  });

  group('DayPlan Actual Nutrition Serialization', () {
    test('toMap and fromMap retain factual fields and slotPhotoUrl accurately', () {
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
        slotPhotoUrl: {'slot-1': 'https://example.com/photos/meal1.jpg'},
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
      expect(reconstituted.slotPhotoUrl['slot-1'], 'https://example.com/photos/meal1.jpg');
      expect(reconstituted.slotCompleted['slot-1'], true);
    });
  });

  group('DietBloc LogActualMeal & ClearActualMeal Events', () {
    test('LogActualMeal sets is_actual, photo_url and is_completed with nutrition details', () async {
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
          photoUrl: 'https://example.com/beef.jpg',
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
      expect(plan.slotPhotoUrl[slotId], 'https://example.com/beef.jpg');

      // Update slot photo
      bloc.add(
        UpdateSlotPhoto(
          date: testDate,
          slotId: slotId,
          photoUrl: 'https://example.com/beef_new.jpg',
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));

      final updatedPlan = bloc.state.dayPlans.firstWhere((p) => p.date.day == testDate.day);
      expect(updatedPlan.slotPhotoUrl[slotId], 'https://example.com/beef_new.jpg');

      // Now clear actual meal - should completely purge all slot data including planned meals
      bloc.add(ClearActualMeal(date: testDate, slotId: slotId));
      await Future.delayed(const Duration(milliseconds: 100));

      final clearedPlan = bloc.state.dayPlans.firstWhere((p) => p.date.day == testDate.day);
      expect(clearedPlan.slotMeals[slotId], isNull);
      expect(clearedPlan.slotIsActual[slotId], isNull);
      expect(clearedPlan.slotActualMealName[slotId], isNull);
      expect(clearedPlan.slotCalories[slotId], isNull);
      expect(clearedPlan.slotPhotoUrl[slotId], isNull);

      await bloc.close();
    });

    test('ScheduleMealToSlot copies meal macros scaled by multiplier and sets is_actual to true', () async {
      final bloc = DietBloc();
      final testDate = DateTime(2026, 9, 3);
      const slotId = 'slot-dinner';

      final testMeal = Meal(
        id: 'meal-noodles-sausage',
        name: 'Noodles with Sausage',
        category: 'Dinner',
        ingredients: ['Noodles', 'Sausage', 'Egg'],
        calories: 500.0,
        protein: 25.0,
        fats: 20.0,
        carbs: 55.0,
        fiber: 4.0,
        aiBreakdown: [
          {'name': 'Egg Noodles', 'weight_g': 150, 'calories': 250},
          {'name': 'Smoked Sausage', 'weight_g': 100, 'calories': 250},
        ],
      );

      // Add meal to library first
      bloc.add(AddMealToLibrary(testMeal));
      await Future.delayed(const Duration(milliseconds: 50));

      // Schedule meal at 2x multiplier
      bloc.add(
        ScheduleMealToSlot(
          date: testDate,
          slotId: slotId,
          mealId: testMeal.id,
          multiplier: 2.0,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));

      final plan = bloc.state.dayPlans.firstWhere((p) => p.date.day == testDate.day);
      expect(plan.slotIsActual[slotId], true);
      expect(plan.slotCompleted[slotId], true);
      expect(plan.slotActualMealName[slotId], 'Noodles with Sausage');
      expect(plan.slotCalories[slotId], 1000.0);
      expect(plan.slotProtein[slotId], 50.0);
      expect(plan.slotFats[slotId], 40.0);
      expect(plan.slotCarbs[slotId], 110.0);
      expect(plan.slotFiber[slotId], 8.0);
      expect(plan.slotUserNote[slotId], 'Serving size: 2x');

      // Verify scaled AI breakdown
      final breakdown = plan.slotAiBreakdown[slotId] as List;
      expect(breakdown.length, 2);
      expect(breakdown[0]['calories'], 500);
      expect(breakdown[0]['weight_g'], 300);
      expect(breakdown[1]['calories'], 500);
      expect(breakdown[1]['weight_g'], 200);

      // Clearing meal removes slot data
      bloc.add(ScheduleMealToSlot(date: testDate, slotId: slotId, mealId: null));
      await Future.delayed(const Duration(milliseconds: 100));

      final clearedPlan = bloc.state.dayPlans.firstWhere((p) => p.date.day == testDate.day);
      expect(clearedPlan.slotMeals[slotId], isNull);
      expect(clearedPlan.slotIsActual[slotId], isNull);
      expect(clearedPlan.slotCalories[slotId], isNull);

      await bloc.close();
    });
  });

  group('MealNutritionBreakdownDialog Widget Tests', () {
    testWidgets('renders all nutrition badges, breakdown items, and user note', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

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
      expect(find.text('+ Add Ingredient'), findsOneWidget);
    });

    testWidgets('adds missing ingredient and recalculates total meal macros accurately', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = DietBloc();
      final testDate = DateTime(2026, 9, 2);

      await tester.pumpWidget(
        BlocProvider<DietBloc>.value(
          value: bloc,
          child: MaterialApp(
            home: Scaffold(
              body: MealNutritionBreakdownDialog(
                date: testDate,
                slotId: 'slot-1',
                slotName: 'Lunch',
                mealName: 'Salad Greens Bowl',
                calories: 50.0,
                protein: 2.0,
                fats: 0.5,
                carbs: 8.0,
                fiber: 3.0,
                aiBreakdown: [
                  {'name': 'Mixed Greens', 'weight': '100g', 'calories': 50},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap + Add Ingredient
      final addBtn = find.text('+ Add Ingredient');
      expect(addBtn, findsOneWidget);
      await tester.ensureVisible(addBtn);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Verify inline form is open
      expect(find.text('Add Missing Ingredient'), findsOneWidget);

      // Enter ingredient name "Canned Tuna"
      final nameField = find.widgetWithText(TextField, 'Ingredient Name');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Canned Tuna');

      // Tap "Add Item"
      final submitAddBtn = find.widgetWithText(ElevatedButton, 'Add Item');
      expect(submitAddBtn, findsOneWidget);
      await tester.tap(submitAddBtn);
      await tester.pumpAndSettle();

      // Verify Canned Tuna is now in the breakdown
      expect(find.text('Canned Tuna'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);

      // Verify calories increased from 50 to 150 kcal (50 + 100 for 100g tuna)
      expect(find.text('150 kcal'), findsOneWidget);
    });
  });

  group('Daily Calorie Target & Planner Header Tests', () {
    test('DietBloc default dailyCalorieTarget is 2000.0 and updates via SetDailyCalorieTarget', () async {
      final bloc = DietBloc();
      expect(bloc.state.dailyCalorieTarget, 2000.0);

      bloc.add(SetDailyCalorieTarget(2400.0));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.dailyCalorieTarget, 2400.0);

      // Verify serialization
      final json = bloc.state.toJson();
      expect(json['dailyCalorieTarget'], 2400.0);

      final restored = DietState.fromJson(json);
      expect(restored.dailyCalorieTarget, 2400.0);

      await bloc.close();
    });

    test('DietState fromJson preserves user created custom meals alongside starter meals', () {
      final userMeal = Meal(
        id: 'user-custom-salad',
        name: 'My Special Tuna Salad',
        category: 'Lunch',
        ingredients: ['Tuna 150g', 'Lettuce 100g'],
        calories: 350.0,
        protein: 40.0,
        fats: 10.0,
        carbs: 5.0,
        fiber: 2.0,
      );

      final state = DietState(
        mealsLibrary: [userMeal],
        dayPlans: [],
        mealSlots: [],
        dailyCalorieTarget: 2100.0,
      );

      final json = state.toJson();
      final restored = DietState.fromJson(json);

      expect(restored.mealsLibrary.any((m) => m.id == 'user-custom-salad'), isTrue);
      expect(restored.mealsLibrary.firstWhere((m) => m.id == 'user-custom-salad').name, 'My Special Tuna Salad');
      expect(restored.dailyCalorieTarget, 2100.0);
    });

    testWidgets('Planner Daily Goal summary card renders without overflow on 360px width and edits target', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bloc = DietBloc();

      await tester.pumpWidget(
        BlocProvider<DietBloc>.value(
          value: bloc,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check header items
      expect(find.text('Daily Goal'), findsOneWidget);
      expect(find.text('Target: 2000 kcal'), findsOneWidget);
      expect(find.text('2000 kcal remaining'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Tap Target: 2000 kcal chip
      final targetChip = find.text('Target: 2000 kcal');
      await tester.tap(targetChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify dialog opened
      expect(find.text('Daily Calorie Target'), findsOneWidget);

      // Tap quick preset "2500 kcal"
      final preset2500 = find.text('2500 kcal');
      expect(preset2500, findsOneWidget);
      await tester.tap(preset2500);
      await tester.pump();

      // Save target
      final saveBtn = find.text('Save Target');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify state and UI updated
      expect(find.text('Target: 2500 kcal'), findsOneWidget);
      expect(find.text('2500 kcal remaining'), findsOneWidget);
    });
  });

  group('MealsLibraryScreen Category Navigation & Filter Sync Tests', () {
    testWidgets('Pre-selects category chip, keeps filter chips interactive, and picks meal', (WidgetTester tester) async {
      final bloc = DietBloc();
      String? pickedMealId;

      await tester.pumpWidget(
        BlocProvider<DietBloc>.value(
          value: bloc,
          child: MaterialApp(
            home: MealsLibraryScreen(
              initialCategory: 'Breakfast',
              targetSlotId: 'slot-breakfast',
              targetSlotName: 'Breakfast',
              onMealPicked: (id) {
                pickedMealId = id;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Check title shows "Add to Breakfast"
      expect(find.text('Add to Breakfast'), findsOneWidget);

      // 2. Check "Breakfast" chip is selected and Breakfast meal is visible
      expect(find.text('Oatmeal with Berries'), findsOneWidget);
      // Lunch meal should not be visible under Breakfast filter
      expect(find.text('Grilled Chicken Salad'), findsNothing);

      // 3. Category chips must remain visible and interactive: tap "Lunch"
      final lunchChip = find.text('Lunch');
      expect(lunchChip, findsOneWidget);
      await tester.tap(lunchChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Now Lunch meal is visible, Oatmeal is hidden
      expect(find.text('Grilled Chicken Salad'), findsOneWidget);
      expect(find.text('Oatmeal with Berries'), findsNothing);

      // 4. Tap "All" chip
      final allChip = find.text('All');
      expect(allChip, findsOneWidget);
      await tester.tap(allChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Both meals should now be visible
      expect(find.text('Grilled Chicken Salad'), findsOneWidget);
      expect(find.text('Oatmeal with Berries'), findsOneWidget);

      // 5. Select a meal and verify onMealPicked is fired
      final selectButton = find.text('Select').first;
      await tester.tap(selectButton);
      await tester.pump();

      expect(pickedMealId, isNotNull);
    });
  });

  group('MealPhotoService Widget Tests', () {
    testWidgets('buildMealImage renders network image and local path fallback without exceptions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MealPhotoService.buildMealImage(
                  photoUrl: 'https://example.com/food.jpg',
                  width: 50,
                  height: 50,
                ),
                MealPhotoService.buildMealImage(
                  photoUrl: 'non_existent_local_file.jpg',
                  width: 50,
                  height: 50,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(Image), findsNWidgets(2));
    });
  });

  group('ReportExportService Tests', () {
    test('generateHtmlReport produces valid responsive HTML with summary stats and breakdown', () {
      final state = DietState(
        mealsLibrary: const [],
        mealSlots: [MealSlotConfig(id: 'breakfast', name: 'Breakfast', orderIndex: 0)],
        dailyCalorieTarget: 2200.0,
        dayPlans: [
          DayPlan(
            date: DateTime(2026, 9, 6),
            slotMeals: const {},
            slotIsActual: {'breakfast': true},
            slotActualMealName: {'breakfast': 'Omelette & Avocado'},
            slotCalories: {'breakfast': 450.0},
            slotProtein: {'breakfast': 28.0},
            slotFats: {'breakfast': 32.0},
            slotCarbs: {'breakfast': 8.0},
            slotFiber: {'breakfast': 5.0},
            slotAiBreakdown: {
              'breakfast': [
                {'name': 'Eggs', 'weight_g': 120, 'calories': 180},
                {'name': 'Avocado', 'weight_g': 50, 'calories': 80},
              ]
            },
          ),
        ],
      );

      final html = ReportExportService.generateHtmlReport(
        state: state,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 7),
        userEmail: 'user@example.com',
      );

      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('PlateMate Nutrition Report'));
      expect(html, contains('user@example.com'));
      expect(html, contains('2200 kcal'));
      expect(html, contains('Omelette &amp; Avocado'));
      expect(html, contains('450 kcal'));
      expect(html, contains('Eggs'));
      expect(html, contains('Avocado'));
    });
  });

  group('Planner Dynamic Date Navigation & Report Export UI Tests', () {
    testWidgets('renders dynamic week strip, navigates weeks forward/back, and opens report dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dietBloc = DietBloc();

      await tester.pumpWidget(
        BlocProvider<DietBloc>.value(
          value: dietBloc,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify week selector is rendered
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // 2. Navigate to previous week
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      // "Today" button should now be visible
      expect(find.text('Today'), findsOneWidget);

      // 3. Tap "Today" to jump back
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // 4. Open Settings Dialog
      final settingsButton = find.byIcon(Icons.settings);
      expect(settingsButton, findsOneWidget);
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      // Verify "Export Nutrition Report" tile is present
      expect(find.text('Export Nutrition Report'), findsOneWidget);

      // 5. Tap Export Nutrition Report
      await tester.tap(find.text('Export Nutrition Report'));
      await tester.pumpAndSettle();

      // Verify Export Report modal dialog is displayed
      expect(find.text('Export HTML Report'), findsOneWidget);
      expect(find.text('Last 7 Days'), findsOneWidget);
      expect(find.text('Last 30 Days'), findsOneWidget);
      expect(find.text('Share Report'), findsOneWidget);

      // 6. Close export dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Export HTML Report'), findsNothing);
    });
  });

  group('Edit Existing Meal in Meals Library Tests', () {
    testWidgets('opens edit meal dialog, updates title, weights, adds item, recalculates and saves changes', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dietBloc = DietBloc();

      await tester.pumpWidget(
        BlocProvider<DietBloc>.value(
          value: dietBloc,
          child: const MaterialApp(
            home: MealsLibraryScreen(isTab: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Find and verify 'Grilled Chicken Salad' is in the library
      expect(find.text('Grilled Chicken Salad'), findsOneWidget);

      // 2. Tap the edit icon on the first meal card
      final editButton = find.byIcon(Icons.edit_outlined).first;
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // 3. Verify Edit Meal Dialog is displayed
      expect(find.text('Edit Meal'), findsOneWidget);
      expect(find.text('Ingredients & Portions'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // 4. Edit meal name
      final nameField = find.widgetWithText(TextFormField, 'Meal Name *');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Super Chicken Salad Deluxe');
      await tester.pumpAndSettle();

      // 5. Add a new ingredient
      final addItemButton = find.text('Add Item');
      expect(addItemButton, findsOneWidget);
      await tester.tap(addItemButton);
      await tester.pumpAndSettle();

      // Enter name and weight for the newly added item
      final lastItemNameField = find.widgetWithText(TextFormField, 'Item Name').last;
      await tester.enterText(lastItemNameField, 'Avocado');
      await tester.pumpAndSettle();

      final lastWeightField = find.widgetWithText(TextFormField, 'Portion / Weight').last;
      await tester.enterText(lastWeightField, '50g');
      await tester.pumpAndSettle();

      // 6. Tap "Save Changes"
      final saveButton = find.text('Save Changes');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // 7. Verify dialog is closed and library shows updated meal title
      expect(find.text('Edit Meal'), findsNothing);
      expect(find.text('Super Chicken Salad Deluxe'), findsOneWidget);

      // Verify in bloc state
      final updatedMeal = dietBloc.state.mealsLibrary.firstWhere(
        (m) => m.name == 'Super Chicken Salad Deluxe',
      );
      expect(updatedMeal.ingredients.any((i) => i.contains('Avocado')), isTrue);
      expect(updatedMeal.calories, isNotNull);
      expect(updatedMeal.calories!, greaterThan(300.0));
    });
  });
}

