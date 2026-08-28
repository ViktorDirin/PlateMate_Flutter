import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:platemate/models/day_plan.dart';
import 'package:platemate/blocs/diet_bloc.dart';

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

  group('DayPlan Completion Serialization Tests', () {
    test('toMap and fromMap parse slotCompleted and slotCompletedAt correctly', () {
      final date = DateTime(2026, 8, 28);
      final completedTime = DateTime(2026, 8, 28, 8, 30);
      final original = DayPlan(
        date: date,
        slotMeals: {
          'slot-1': ['meal-1'],
        },
        slotCompleted: {
          'slot-1': true,
        },
        slotCompletedAt: {
          'slot-1': completedTime,
        },
      );

      final map = original.toMap();
      final parsed = DayPlan.fromMap(map);

      expect(parsed.slotCompleted['slot-1'], isTrue);
      expect(parsed.slotCompletedAt['slot-1'], equals(completedTime));
    });

    test('fromMap handles missing completion states gracefully', () {
      final date = DateTime(2026, 8, 28);
      final legacyMap = {
        'date': date.toIso8601String(),
        'slotMeals': {
          'slot-1': ['meal-1'],
        },
      };

      final parsed = DayPlan.fromMap(legacyMap);
      expect(parsed.slotCompleted, isEmpty);
      expect(parsed.slotCompletedAt, isEmpty);
    });
  });

  group('DietBloc Completion Event Tests', () {
    test('ToggleMealCompletion sets completion status and updates state', () async {
      final bloc = DietBloc();
      final date = DateTime(2026, 8, 28);
      
      expect(bloc.state.dayPlans, isEmpty);

      bloc.add(ToggleMealCompletion(
        date: date,
        slotId: 'breakfast',
        isCompleted: true,
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<DietState>().having(
            (s) => s.dayPlans.first.slotCompleted['breakfast'],
            'breakfast isCompleted',
            isTrue,
          ),
        ),
      );
    });

    test('UpdateMealCompletionTime updates completedAt in state', () async {
      final bloc = DietBloc();
      final date = DateTime(2026, 8, 28);
      final newTime = DateTime(2026, 8, 28, 9, 15);

      bloc.add(UpdateMealCompletionTime(
        date: date,
        slotId: 'lunch',
        completedAt: newTime,
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<DietState>().having(
            (s) => s.dayPlans.first.slotCompletedAt['lunch'],
            'lunch completedAt',
            equals(newTime),
          ),
        ),
      );
    });
  });
}
