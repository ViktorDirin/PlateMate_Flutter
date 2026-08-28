import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/meal.dart';
import '../models/day_plan.dart';
import '../models/meal_slot_config.dart';

// --- Events ---
abstract class DietEvent {}

class AddMealToLibrary extends DietEvent {
  final Meal meal;
  AddMealToLibrary(this.meal);
}

class DeleteMealFromLibrary extends DietEvent {
  final String mealId;
  DeleteMealFromLibrary(this.mealId);
}

class ScheduleMeal extends DietEvent {
  final DateTime date;
  final String category;
  final String? mealId;
  ScheduleMeal({required this.date, required this.category, this.mealId});
}

class AddSnackToDay extends DietEvent {
  final DateTime date;
  final String mealId;
  AddSnackToDay({required this.date, required this.mealId});
}

class RemoveSnackFromDay extends DietEvent {
  final DateTime date;
  final int index;
  RemoveSnackFromDay({required this.date, required this.index});
}

class ToggleGroceryItem extends DietEvent {
  final String item;
  ToggleGroceryItem(this.item);
}

class AddManualGroceryItem extends DietEvent {
  final String item;
  AddManualGroceryItem(this.item);
}

class ClearCheckedGrocery extends DietEvent {}

// Custom slot configuration events
class AddMealSlot extends DietEvent {
  final MealSlotConfig slot;
  AddMealSlot(this.slot);
}

class UpdateMealSlot extends DietEvent {
  final MealSlotConfig slot;
  UpdateMealSlot(this.slot);
}

class DeleteMealSlot extends DietEvent {
  final String slotId;
  DeleteMealSlot(this.slotId);
}

class ReorderMealSlots extends DietEvent {
  final int oldIndex;
  final int newIndex;
  ReorderMealSlots({required this.oldIndex, required this.newIndex});
}

class ScheduleMealToSlot extends DietEvent {
  final DateTime date;
  final String slotId;
  final String? mealId;
  ScheduleMealToSlot({required this.date, required this.slotId, this.mealId});
}

class AddSnackToSlot extends DietEvent {
  final DateTime date;
  final String slotId;
  final String mealId;
  AddSnackToSlot({required this.date, required this.slotId, required this.mealId});
}

class RemoveSnackFromSlot extends DietEvent {
  final DateTime date;
  final String slotId;
  final int index;
  RemoveSnackFromSlot({required this.date, required this.slotId, required this.index});
}

class SyncDataFromSupabase extends DietEvent {}

// --- State ---
class DietState {
  final List<Meal> mealsLibrary;
  final List<DayPlan> dayPlans;
  final List<String> crossedIngredients;
  final List<String> manualGroceryItems;
  final List<MealSlotConfig> mealSlots;

  DietState({
    required this.mealsLibrary,
    required this.dayPlans,
    this.crossedIngredients = const [],
    this.manualGroceryItems = const [],
    required this.mealSlots,
  });

  DietState copyWith({
    List<Meal>? mealsLibrary,
    List<DayPlan>? dayPlans,
    List<String>? crossedIngredients,
    List<String>? manualGroceryItems,
    List<MealSlotConfig>? mealSlots,
  }) {
    return DietState(
      mealsLibrary: mealsLibrary ?? this.mealsLibrary,
      dayPlans: dayPlans ?? this.dayPlans,
      crossedIngredients: crossedIngredients ?? this.crossedIngredients,
      manualGroceryItems: manualGroceryItems ?? this.manualGroceryItems,
      mealSlots: mealSlots ?? this.mealSlots,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mealsLibrary': mealsLibrary.map((m) => m.toMap()).toList(),
      'dayPlans': dayPlans.map((d) => d.toMap()).toList(),
      'crossedIngredients': crossedIngredients,
      'manualGroceryItems': manualGroceryItems,
      'mealSlots': mealSlots.map((s) => s.toMap()).toList(),
    };
  }

  factory DietState.fromJson(Map<String, dynamic> json) {
    final parsedLibrary = (json['mealsLibrary'] as List<dynamic>?)
        ?.map((m) => Meal.fromMap(m as Map<String, dynamic>))
        .toList();
    final parsedPlans = (json['dayPlans'] as List<dynamic>?)
        ?.map((d) => DayPlan.fromMap(d as Map<String, dynamic>))
        .toList();
    final parsedCrossed = (json['crossedIngredients'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList();
    final parsedManual = (json['manualGroceryItems'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList();
    final parsedSlots = (json['mealSlots'] as List<dynamic>?)
        ?.map((s) => MealSlotConfig.fromMap(s as Map<String, dynamic>))
        .toList();

    return DietState(
      mealsLibrary: parsedLibrary ?? _defaultMeals(),
      dayPlans: parsedPlans ?? [],
      crossedIngredients: parsedCrossed ?? [],
      manualGroceryItems: parsedManual ?? [],
      mealSlots: parsedSlots ?? _defaultSlots(),
    );
  }

  static List<MealSlotConfig> _defaultSlots() {
    return [
      MealSlotConfig(id: '00000000-0000-0000-0000-000000000001', name: 'Breakfast', orderIndex: 0, isEnabled: true),
      MealSlotConfig(id: '00000000-0000-0000-0000-000000000002', name: 'Lunch', orderIndex: 1, isEnabled: true),
      MealSlotConfig(id: '00000000-0000-0000-0000-000000000003', name: 'Dinner', orderIndex: 2, isEnabled: true),
      MealSlotConfig(id: '00000000-0000-0000-0000-000000000004', name: 'Snacks', orderIndex: 3, isEnabled: true),
    ];
  }

  static List<Meal> _defaultMeals() {
    return [
      Meal(
        name: 'Oatmeal with Berries',
        category: 'Breakfast',
        ingredients: ['Oats', 'Almond Milk', 'Blueberries', 'Honey'],
      ),
      Meal(
        name: 'Grilled Chicken Salad',
        category: 'Lunch',
        ingredients: ['Chicken Breast', 'Mixed Greens', 'Cherry Tomatoes', 'Olive Oil'],
      ),
      Meal(
        name: 'Salmon with Steamed Rice',
        category: 'Dinner',
        ingredients: ['Salmon Fillet', 'White Rice', 'Broccoli', 'Soy Sauce'],
      ),
      Meal(
        name: 'Greek Yogurt & Walnuts',
        category: 'Snack',
        ingredients: ['Greek Yogurt', 'Walnuts', 'Honey'],
      ),
    ];
  }
}

// --- Bloc ---
class DietBloc extends HydratedBloc<DietEvent, DietState> {
  DietBloc() : super(DietState(
      mealsLibrary: DietState._defaultMeals(),
      dayPlans: [],
      mealSlots: DietState._defaultSlots(),
  )) {
    on<AddMealToLibrary>(_onAddMealToLibrary);
    on<DeleteMealFromLibrary>(_onDeleteMealFromLibrary);
    on<ScheduleMeal>(_onScheduleMeal);
    on<AddSnackToDay>(_onAddSnackToDay);
    on<RemoveSnackFromDay>(_onRemoveSnackFromDay);
    on<ToggleGroceryItem>(_onToggleGroceryItem);
    on<AddManualGroceryItem>(_onAddManualGroceryItem);
    on<ClearCheckedGrocery>(_onClearCheckedGrocery);

    // Custom Slots
    on<AddMealSlot>(_onAddMealSlot);
    on<UpdateMealSlot>(_onUpdateMealSlot);
    on<DeleteMealSlot>(_onDeleteMealSlot);
    on<ReorderMealSlots>(_onReorderMealSlots);
    on<ScheduleMealToSlot>(_onScheduleMealToSlot);
    on<AddSnackToSlot>(_onAddSnackToSlot);
    on<RemoveSnackFromSlot>(_onRemoveSnackFromSlot);

    // Sync
    on<SyncDataFromSupabase>(_onSyncDataFromSupabase);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _onAddMealToLibrary(AddMealToLibrary event, Emitter<DietState> emit) {
    final updated = List<Meal>.from(state.mealsLibrary)..add(event.meal);
    emit(state.copyWith(mealsLibrary: updated));

    // Supabase background sync
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      client.from('meals').insert({
        'id': event.meal.id,
        'name': event.meal.name,
        'category': event.meal.category,
        'ingredients': event.meal.ingredients,
        'user_id': userId,
      }).then((_) {}, onError: (e) => debugPrint('Supabase meals insert error: $e'));
    }
  }

  void _onDeleteMealFromLibrary(DeleteMealFromLibrary event, Emitter<DietState> emit) {
    final updatedLibrary = state.mealsLibrary.where((m) => m.id != event.mealId).toList();

    final updatedPlans = state.dayPlans.map((plan) {
      final slotMeals = Map<String, List<String>>.from(plan.slotMeals);
      final keysToUpdate = <String>[];
      
      slotMeals.forEach((slotId, list) {
        if (list.contains(event.mealId)) {
          keysToUpdate.add(slotId);
        }
      });

      for (var key in keysToUpdate) {
        final updatedList = slotMeals[key]!.where((id) => id != event.mealId).toList();
        if (updatedList.isEmpty) {
          slotMeals.remove(key);
        } else {
          slotMeals[key] = updatedList;
        }
      }

      return plan.copyWith(slotMeals: slotMeals);
    }).toList();

    emit(state.copyWith(
      mealsLibrary: updatedLibrary,
      dayPlans: updatedPlans,
    ));

    // Supabase background sync
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      client.from('meals').delete().eq('id', event.mealId).then((_) {}, onError: (e) => debugPrint('Supabase meals delete error: $e'));
    }
  }

  // Legacy ScheduleMeal event fallback
  void _onScheduleMeal(ScheduleMeal event, Emitter<DietState> emit) {
    final category = event.category.toLowerCase();
    String slotId;
    if (category == 'breakfast') {
      slotId = '00000000-0000-0000-0000-000000000001';
    } else if (category == 'lunch') {
      slotId = '00000000-0000-0000-0000-000000000002';
    } else if (category == 'dinner') {
      slotId = '00000000-0000-0000-0000-000000000003';
    } else {
      slotId = '00000000-0000-0000-0000-000000000004';
    }
    add(ScheduleMealToSlot(date: event.date, slotId: slotId, mealId: event.mealId));
  }

  // Legacy AddSnackToDay event fallback
  void _onAddSnackToDay(AddSnackToDay event, Emitter<DietState> emit) {
    add(AddSnackToSlot(date: event.date, slotId: '00000000-0000-0000-0000-000000000004', mealId: event.mealId));
  }

  // Legacy RemoveSnackFromDay event fallback
  void _onRemoveSnackFromDay(RemoveSnackFromDay event, Emitter<DietState> emit) {
    add(RemoveSnackFromSlot(date: event.date, slotId: '00000000-0000-0000-0000-000000000004', index: event.index));
  }

  void _onToggleGroceryItem(ToggleGroceryItem event, Emitter<DietState> emit) {
    final itemLower = event.item.toLowerCase().trim();
    final updated = List<String>.from(state.crossedIngredients);
    if (updated.contains(itemLower)) {
      updated.remove(itemLower);
    } else {
      updated.add(itemLower);
    }
    emit(state.copyWith(crossedIngredients: updated));
  }

  void _onAddManualGroceryItem(AddManualGroceryItem event, Emitter<DietState> emit) {
    final trimmed = event.item.trim();
    if (trimmed.isEmpty) return;
    
    final updated = List<String>.from(state.manualGroceryItems);
    if (!updated.any((e) => e.toLowerCase() == trimmed.toLowerCase())) {
      updated.add(trimmed);
    }
    emit(state.copyWith(manualGroceryItems: updated));
  }

  void _onClearCheckedGrocery(ClearCheckedGrocery event, Emitter<DietState> emit) {
    final updatedPlans = state.dayPlans.map((plan) {
      final List<String> newCleared = List<String>.from(plan.clearedIngredients);
      
      plan.slotMeals.forEach((slotId, mealIds) {
        for (var mealId in mealIds) {
          final meal = state.mealsLibrary.firstWhere(
            (m) => m.id == mealId,
            orElse: () => Meal(name: '', category: '', ingredients: []),
          );
          for (var ing in meal.ingredients) {
            final ingLower = ing.toLowerCase().trim();
            if (state.crossedIngredients.contains(ingLower)) {
              if (!newCleared.contains(ingLower)) {
                newCleared.add(ingLower);
              }
            }
          }
        }
      });

      return plan.copyWith(clearedIngredients: newCleared);
    }).toList();

    final crossedManual = state.manualGroceryItems.where((item) {
      return state.crossedIngredients.contains(item.toLowerCase().trim());
    }).toList();

    final remainingManual = state.manualGroceryItems.where((item) {
      return !crossedManual.contains(item);
    }).toList();

    emit(state.copyWith(
      dayPlans: updatedPlans,
      manualGroceryItems: remainingManual,
      crossedIngredients: const [],
    ));

    // Supabase background sync
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      for (var plan in updatedPlans) {
        final dateStr = plan.date.toIso8601String().substring(0, 10);
        plan.slotMeals.forEach((slotId, mealIds) {
          client.from('day_plans').upsert({
            'user_id': userId,
            'date': dateStr,
            'slot_id': slotId,
            'meal_ids': mealIds,
            'cleared_ingredients': plan.clearedIngredients,
          }).then((_) {}, onError: (e) => debugPrint('Supabase clear check-upsert error: $e'));
        });
      }
    }
  }

  // Custom Slots management event handlers
  void _onAddMealSlot(AddMealSlot event, Emitter<DietState> emit) {
    final updated = List<MealSlotConfig>.from(state.mealSlots)..add(event.slot);
    emit(state.copyWith(mealSlots: updated));

    // Supabase background sync
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      client.from('slot_configs').insert({
        'id': event.slot.id,
        'name': event.slot.name,
        'order_index': event.slot.orderIndex,
        'is_enabled': event.slot.isEnabled,
        'user_id': userId,
      }).then((_) {}, onError: (e) => debugPrint('Supabase slots insert error: $e'));
    }
  }

  void _onUpdateMealSlot(UpdateMealSlot event, Emitter<DietState> emit) {
    final updated = state.mealSlots.map((s) => s.id == event.slot.id ? event.slot : s).toList();
    emit(state.copyWith(mealSlots: updated));

    // Supabase background sync
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      client.from('slot_configs').update({
        'name': event.slot.name,
        'order_index': event.slot.orderIndex,
        'is_enabled': event.slot.isEnabled,
      }).match({
        'id': event.slot.id,
        'user_id': userId,
      }).then((_) {}, onError: (e) => debugPrint('Supabase slots update error: $e'));
    }
  }

  void _onDeleteMealSlot(DeleteMealSlot event, Emitter<DietState> emit) {
    final updatedSlots = state.mealSlots.where((s) => s.id != event.slotId).toList();

    final updatedPlans = state.dayPlans.map((plan) {
      final slotMeals = Map<String, List<String>>.from(plan.slotMeals);
      slotMeals.remove(event.slotId);
      return plan.copyWith(slotMeals: slotMeals);
    }).toList();

    emit(state.copyWith(
      mealSlots: updatedSlots,
      dayPlans: updatedPlans,
    ));

    // Supabase background sync
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      client.from('slot_configs').delete().match({
        'id': event.slotId,
        'user_id': userId,
      }).then((_) {}, onError: (e) => debugPrint('Supabase slots delete error: $e'));

      for (var plan in updatedPlans) {
        final dateStr = plan.date.toIso8601String().substring(0, 10);
        client.from('day_plans').delete().match({
          'user_id': userId,
          'date': dateStr,
          'slot_id': event.slotId,
        }).then((_) {}, onError: (e) => debugPrint('Supabase slots plan delete error: $e'));
      }
    }
  }

  void _onReorderMealSlots(ReorderMealSlots event, Emitter<DietState> emit) {
    final updated = List<MealSlotConfig>.from(state.mealSlots);
    int newIndex = event.newIndex;
    if (event.oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = updated.removeAt(event.oldIndex);
    updated.insert(newIndex, item);

    for (int i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(orderIndex: i);
    }

    emit(state.copyWith(mealSlots: updated));

    // Supabase background sync
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      for (var slot in updated) {
        client.from('slot_configs').update({
          'order_index': slot.orderIndex,
        }).match({
          'id': slot.id,
          'user_id': userId,
        }).then((_) {}, onError: (e) => debugPrint('Supabase slots reorder error: $e'));
      }
    }
  }

  void _onScheduleMealToSlot(ScheduleMealToSlot event, Emitter<DietState> emit) {
    final plans = List<DayPlan>.from(state.dayPlans);
    final index = plans.indexWhere((p) => _isSameDate(p.date, event.date));
    DayPlan updatedPlan;

    if (index >= 0) {
      final existing = plans[index];
      final slotMeals = Map<String, List<String>>.from(existing.slotMeals);
      if (event.mealId == null) {
        slotMeals.remove(event.slotId);
      } else {
        slotMeals[event.slotId] = [event.mealId!];
      }
      updatedPlan = existing.copyWith(slotMeals: slotMeals);
      plans[index] = updatedPlan;
    } else {
      final Map<String, List<String>> slotMeals = {};
      if (event.mealId != null) {
        slotMeals[event.slotId] = [event.mealId!];
      }
      updatedPlan = DayPlan(date: event.date, slotMeals: slotMeals);
      plans.add(updatedPlan);
    }

    emit(state.copyWith(dayPlans: plans));

    // Supabase background sync
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      final dateStr = event.date.toIso8601String().substring(0, 10);
      if (event.mealId == null) {
        client.from('day_plans').delete().match({
          'user_id': userId,
          'date': dateStr,
          'slot_id': event.slotId,
        }).then((_) {}, onError: (e) => debugPrint('Supabase plan delete error: $e'));
      } else {
        client.from('day_plans').upsert({
          'user_id': userId,
          'date': dateStr,
          'slot_id': event.slotId,
          'meal_ids': [event.mealId!],
          'cleared_ingredients': updatedPlan.clearedIngredients,
        }).then((_) {}, onError: (e) => debugPrint('Supabase plan upsert error: $e'));
      }
    }
  }

  void _onAddSnackToSlot(AddSnackToSlot event, Emitter<DietState> emit) {
    final plans = List<DayPlan>.from(state.dayPlans);
    final index = plans.indexWhere((p) => _isSameDate(p.date, event.date));
    DayPlan updatedPlan;

    if (index >= 0) {
      final existing = plans[index];
      final slotMeals = Map<String, List<String>>.from(existing.slotMeals);
      final currentList = List<String>.from(slotMeals[event.slotId] ?? [])..add(event.mealId);
      slotMeals[event.slotId] = currentList;
      updatedPlan = existing.copyWith(slotMeals: slotMeals);
      plans[index] = updatedPlan;
    } else {
      updatedPlan = DayPlan(
        date: event.date,
        slotMeals: {
          event.slotId: [event.mealId],
        },
      );
      plans.add(updatedPlan);
    }

    emit(state.copyWith(dayPlans: plans));

    // Supabase background sync
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      final dateStr = event.date.toIso8601String().substring(0, 10);
      client.from('day_plans').upsert({
        'user_id': userId,
        'date': dateStr,
        'slot_id': event.slotId,
        'meal_ids': updatedPlan.slotMeals[event.slotId],
        'cleared_ingredients': updatedPlan.clearedIngredients,
      }).then((_) {}, onError: (e) => debugPrint('Supabase snack add upsert error: $e'));
    }
  }

  void _onRemoveSnackFromSlot(RemoveSnackFromSlot event, Emitter<DietState> emit) {
    final plans = List<DayPlan>.from(state.dayPlans);
    final index = plans.indexWhere((p) => _isSameDate(p.date, event.date));

    if (index >= 0) {
      final existing = plans[index];
      final slotMeals = Map<String, List<String>>.from(existing.slotMeals);
      if (slotMeals.containsKey(event.slotId)) {
        final currentList = List<String>.from(slotMeals[event.slotId]!);
        if (event.index >= 0 && event.index < currentList.length) {
          currentList.removeAt(event.index);
          DayPlan updatedPlan;
          if (currentList.isEmpty) {
            slotMeals.remove(event.slotId);
            updatedPlan = existing.copyWith(slotMeals: slotMeals);
          } else {
            slotMeals[event.slotId] = currentList;
            updatedPlan = existing.copyWith(slotMeals: slotMeals);
          }
          plans[index] = updatedPlan;
          emit(state.copyWith(dayPlans: plans));

          // Supabase background sync
          final client = Supabase.instance.client;
          final userId = client.auth.currentUser?.id;
          if (userId != null) {
            final dateStr = event.date.toIso8601String().substring(0, 10);
            if (currentList.isEmpty) {
              client.from('day_plans').delete().match({
                'user_id': userId,
                'date': dateStr,
                'slot_id': event.slotId,
              }).then((_) {}, onError: (e) => debugPrint('Supabase snack delete error: $e'));
            } else {
              client.from('day_plans').upsert({
                'user_id': userId,
                'date': dateStr,
                'slot_id': event.slotId,
                'meal_ids': currentList,
                'cleared_ingredients': updatedPlan.clearedIngredients,
              }).then((_) {}, onError: (e) => debugPrint('Supabase snack remove upsert error: $e'));
            }
          }
        }
      }
    }
  }

  static List<DayPlan> _parseDayPlansFromSupabase(List<dynamic> rows) {
    final Map<String, Map<String, List<String>>> groupedMeals = {};
    final Map<String, List<String>> clearedIngredients = {};
    final Map<String, DateTime> dates = {};

    for (final row in rows) {
      final dateStr = row['date'] as String;
      final date = DateTime.parse(dateStr);
      final slotId = row['slot_id'] as String;
      final List<String> mealIds = List<String>.from(row['meal_ids'] as List<dynamic>? ?? []);
      final List<String> cleared = List<String>.from(row['cleared_ingredients'] as List<dynamic>? ?? []);

      dates[dateStr] = date;
      
      if (!groupedMeals.containsKey(dateStr)) {
        groupedMeals[dateStr] = {};
      }
      groupedMeals[dateStr]![slotId] = mealIds;

      if (!clearedIngredients.containsKey(dateStr)) {
        clearedIngredients[dateStr] = [];
      }
      for (var ing in cleared) {
        if (!clearedIngredients[dateStr]!.contains(ing)) {
          clearedIngredients[dateStr]!.add(ing);
        }
      }
    }

    return groupedMeals.entries.map((entry) {
      final dateStr = entry.key;
      final slotMeals = entry.value;
      return DayPlan(
        date: dates[dateStr]!,
        slotMeals: slotMeals,
        clearedIngredients: clearedIngredients[dateStr] ?? [],
      );
    }).toList();
  }

  Future<void> _onSyncDataFromSupabase(SyncDataFromSupabase event, Emitter<DietState> emit) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 1. Fetch meals
      List<Meal> meals = [];
      try {
        final mealsResponse = await client.from('meals').select().eq('user_id', userId);
        meals = (mealsResponse as List<dynamic>)
            .map((m) => Meal.fromMap(m as Map<String, dynamic>))
            .toList();
      } catch (mealsErr) {
        debugPrint('Error fetching meals from Supabase: $mealsErr');
      }

      if (meals.isEmpty) {
        try {
          final List<Map<String, dynamic>> starterMeals = [
            {
              'name': 'Oatmeal with Berries',
              'category': 'Breakfast',
              'ingredients': ['Oats', 'Almond Milk', 'Blueberries', 'Honey'],
              'user_id': userId,
            },
            {
              'name': 'Grilled Chicken Salad',
              'category': 'Lunch',
              'ingredients': ['Chicken Breast', 'Mixed Greens', 'Cherry Tomatoes', 'Olive Oil'],
              'user_id': userId,
            },
            {
              'name': 'Salmon with Steamed Rice',
              'category': 'Dinner',
              'ingredients': ['Salmon Fillet', 'White Rice', 'Broccoli', 'Soy Sauce'],
              'user_id': userId,
            },
            {
              'name': 'Greek Yogurt & Walnuts',
              'category': 'Snack',
              'ingredients': ['Greek Yogurt', 'Walnuts', 'Honey'],
              'user_id': userId,
            },
          ];
          await client.from('meals').insert(starterMeals);
          final refetchedResponse = await client.from('meals').select().eq('user_id', userId);
          meals = (refetchedResponse as List<dynamic>)
              .map((m) => Meal.fromMap(m as Map<String, dynamic>))
              .toList();
        } catch (seedErr) {
          debugPrint('Error seeding starter meals to Supabase: $seedErr');
        }
      }

      // 2. Fetch slot configs
      List<MealSlotConfig> slots = [];
      try {
        final slotsResponse = await client.from('slot_configs').select().eq('user_id', userId);
        slots = (slotsResponse as List<dynamic>)
            .map((s) => MealSlotConfig(
                  id: s['id'] as String,
                  name: s['name'] as String? ?? '',
                  orderIndex: s['order_index'] as int? ?? 0,
                  isEnabled: s['is_enabled'] as bool? ?? true,
                ))
            .toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      } catch (slotsErr) {
        debugPrint('Error fetching slots from Supabase: $slotsErr');
      }

      if (slots.isEmpty) {
        try {
          final List<Map<String, dynamic>> defaultSlots = [
            {'id': const Uuid().v4(), 'name': 'Breakfast', 'order_index': 0, 'is_enabled': true, 'user_id': userId},
            {'id': const Uuid().v4(), 'name': 'Lunch', 'order_index': 1, 'is_enabled': true, 'user_id': userId},
            {'id': const Uuid().v4(), 'name': 'Dinner', 'order_index': 2, 'is_enabled': true, 'user_id': userId},
            {'id': const Uuid().v4(), 'name': 'Snacks', 'order_index': 3, 'is_enabled': true, 'user_id': userId},
          ];
          await client.from('slot_configs').insert(defaultSlots);
          
          final refetchedSlotsResponse = await client.from('slot_configs').select().eq('user_id', userId);
          slots = (refetchedSlotsResponse as List<dynamic>)
              .map((s) => MealSlotConfig(
                    id: s['id'] as String,
                    name: s['name'] as String? ?? '',
                    orderIndex: s['order_index'] as int? ?? 0,
                    isEnabled: s['is_enabled'] as bool? ?? true,
                  ))
              .toList()
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        } catch (slotsSeedErr) {
          debugPrint('Error seeding slots to Supabase: $slotsSeedErr');
        }
      }

      if (slots.isEmpty) {
        slots = DietState._defaultSlots();
      }

      // 3. Fetch day plans
      final plansResponse = await client.from('day_plans').select();
      final plans = _parseDayPlansFromSupabase(plansResponse as List<dynamic>);

      emit(state.copyWith(
        mealsLibrary: meals,
        mealSlots: slots,
        dayPlans: plans,
      ));
    } catch (e) {
      debugPrint('Error syncing from Supabase: $e');
    }
  }

  // --- HydratedBloc Implementation ---
  @override
  DietState? fromJson(Map<String, dynamic> json) => DietState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(DietState state) => state.toJson();
}
