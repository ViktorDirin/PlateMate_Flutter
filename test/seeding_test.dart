import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:platemate/blocs/diet_bloc.dart';
import 'package:platemate/ui/screens/grocery_list_screen.dart';

class MockStorage implements Storage {
  @override
  dynamic read(String key) => null;

  @override
  Future<void> write(String key, dynamic value) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HydratedBloc.storage = MockStorage();
  });
  group('Default Seeding Tests', () {
    test('Default slots and meals are defined correctly', () {
      final bloc = DietBloc();
      final defaultSlots = bloc.state.mealSlots;
      expect(defaultSlots, isNotEmpty);
      expect(defaultSlots.length, 4);
      expect(defaultSlots[0].name, 'Breakfast');

      final defaultMeals = bloc.state.mealsLibrary;
      expect(defaultMeals, isNotEmpty);
      expect(defaultMeals.length, 4);
      expect(defaultMeals[0].name, 'Oatmeal with Berries');
      expect(defaultMeals[1].name, 'Grilled Chicken Salad');
      expect(defaultMeals[2].name, 'Salmon with Steamed Rice');
      expect(defaultMeals[3].name, 'Greek Yogurt & Walnuts');
    });
  });

  group('Grocery List Clear Dialog Widget Tests', () {
    testWidgets('GroceryListScreen clear action dialog triggers correctly', (WidgetTester tester) async {
      final bloc = DietBloc();
      
      // Inject manual item to make sure finalKeys is not empty and buttons are enabled
      bloc.emit(bloc.state.copyWith(
        manualGroceryItems: ['Eggs'],
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: const Scaffold(
              body: GroceryListScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the delete/clear button by its icon
      final clearButtonFinder = find.byIcon(Icons.delete_outline);
      expect(clearButtonFinder, findsOneWidget);

      // Tap the clear button
      await tester.tap(clearButtonFinder);
      await tester.pumpAndSettle();

      // Verify that the confirmation dialog appears
      expect(find.text('Clear Purchased Items?'), findsOneWidget);
      expect(find.text('This will remove all checked items from your grocery list.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });
  });
}
