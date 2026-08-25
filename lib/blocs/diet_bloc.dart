import 'dart:async';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/diet_plan.dart';

// --- Events ---
abstract class DietEvent {}

class LoadDiets extends DietEvent {}

class SetDefaultDiet extends DietEvent {
  final String id;
  SetDefaultDiet(this.id);
}

class AddDiet extends DietEvent {
  final String name;
  AddDiet(this.name);
}

class UpdateDiet extends DietEvent {
  final DietPlan diet;
  UpdateDiet(this.diet);
}

class DeleteDiet extends DietEvent {
  final String id;
  DeleteDiet(this.id);
}

class SyncWithCloud extends DietEvent {}

// --- Library Events ---
class AddLibraryMeal extends DietEvent {
  final Meal meal;
  AddLibraryMeal(this.meal);
}

class UpdateLibraryMeal extends DietEvent {
  final Meal meal;
  UpdateLibraryMeal(this.meal);
}

class DeleteLibraryMeal extends DietEvent {
  final String id;
  DeleteLibraryMeal(this.id);
}

class ReorderLibraryMeals extends DietEvent {
  final String category;
  final int oldIndex;
  final int newIndex;
  ReorderLibraryMeals(this.category, this.oldIndex, this.newIndex);
}

// --- State ---
class DietState {
  final List<DietPlan> diets;
  final String? defaultDietId;
  final bool isSyncing;
  final bool syncFailed;
  final List<Meal> libraryMeals;

  DietState({
    required this.diets,
    this.defaultDietId,
    this.isSyncing = false,
    this.syncFailed = false,
    required this.libraryMeals,
  });

  DietState copyWith({
    List<DietPlan>? diets,
    String? defaultDietId,
    bool? isSyncing,
    bool? syncFailed,
    List<Meal>? libraryMeals,
  }) {
    return DietState(
      diets: diets ?? this.diets,
      defaultDietId: defaultDietId ?? this.defaultDietId,
      isSyncing: isSyncing ?? this.isSyncing,
      syncFailed: syncFailed ?? this.syncFailed,
      libraryMeals: libraryMeals ?? this.libraryMeals,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'diets': diets.map((d) => d.toJson()).toList(),
      'defaultDietId': defaultDietId,
      'libraryMeals': libraryMeals.map((m) => m.toJson()).toList(),
    };
  }

  factory DietState.fromJson(Map<String, dynamic> json) {
    final parsedLibrary = (json['libraryMeals'] as List<dynamic>?)
        ?.map((m) => Meal.fromJson(m as Map<String, dynamic>))
        .toList();
    
    return DietState(
      diets: (json['diets'] as List<dynamic>?)
              ?.map((d) => DietPlan.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      defaultDietId: json['defaultDietId'] as String?,
      libraryMeals: parsedLibrary ?? _defaultLibraryMeals(),
    );
  }

  static List<Meal> _defaultLibraryMeals() {
    return [
      Meal(
        name: 'Овсяная каша с бананом',
        category: 'Breakfast',
        time: '08:30',
        date: '',
        sortOrder: 0,
        ingredients: [
          Ingredient(name: 'Овсяные хлопья', quantity: 50, unit: 'gr'),
          Ingredient(name: 'Банан', quantity: 1, unit: 'pcs'),
          Ingredient(name: 'Молоко', quantity: 150, unit: 'ml'),
        ],
      ),
      Meal(
        name: 'Омлет с томатами',
        category: 'Breakfast',
        time: '09:00',
        date: '',
        sortOrder: 1,
        ingredients: [
          Ingredient(name: 'Яйца', quantity: 3, unit: 'pcs'),
          Ingredient(name: 'Томаты', quantity: 1, unit: 'pcs'),
          Ingredient(name: 'Масло оливковое', quantity: 5, unit: 'ml'),
        ],
      ),
      Meal(
        name: 'Куриная грудка с рисом',
        category: 'Lunch',
        time: '13:00',
        date: '',
        sortOrder: 0,
        ingredients: [
          Ingredient(name: 'Куриное филе', quantity: 150, unit: 'gr'),
          Ingredient(name: 'Рис отварной', quantity: 120, unit: 'gr'),
          Ingredient(name: 'Брокколи', quantity: 70, unit: 'gr'),
        ],
      ),
      Meal(
        name: 'Паста с тунцом',
        category: 'Lunch',
        time: '14:00',
        date: '',
        sortOrder: 1,
        ingredients: [
          Ingredient(name: 'Паста', quantity: 80, unit: 'gr'),
          Ingredient(name: 'Тунец консервированный', quantity: 100, unit: 'gr'),
          Ingredient(name: 'Черри', quantity: 50, unit: 'gr'),
        ],
      ),
      Meal(
        name: 'Лосось на гриле с аспарагусом',
        category: 'Dinner',
        time: '19:00',
        date: '',
        sortOrder: 0,
        ingredients: [
          Ingredient(name: 'Лосось филе', quantity: 160, unit: 'gr'),
          Ingredient(name: 'Спарка (аспарагус)', quantity: 100, unit: 'gr'),
          Ingredient(name: 'Лимонный сок', quantity: 10, unit: 'ml'),
        ],
      ),
      Meal(
        name: 'Салат легкий с сыром сиртаки',
        category: 'Dinner',
        time: '19:30',
        date: '',
        sortOrder: 1,
        ingredients: [
          Ingredient(name: 'Огурец', quantity: 100, unit: 'gr'),
          Ingredient(name: 'Помидор', quantity: 100, unit: 'gr'),
          Ingredient(name: 'Сыр Сиртаки', quantity: 50, unit: 'gr'),
        ],
      ),
    ];
  }
}

// --- Bloc ---
class DietBloc extends HydratedBloc<DietEvent, DietState> {
  DietBloc() : super(DietState(diets: [], libraryMeals: DietState._defaultLibraryMeals())) {
    on<LoadDiets>(_onLoadDiets);
    on<SetDefaultDiet>(_onSetDefaultDiet);
    on<AddDiet>(_onAddDiet);
    on<UpdateDiet>(_onUpdateDiet);
    on<DeleteDiet>(_onDeleteDiet);
    on<SyncWithCloud>(_onSyncWithCloud);

    // Library handlers
    on<AddLibraryMeal>(_onAddLibraryMeal);
    on<UpdateLibraryMeal>(_onUpdateLibraryMeal);
    on<DeleteLibraryMeal>(_onDeleteLibraryMeal);
    on<ReorderLibraryMeals>(_onReorderLibraryMeals);
  }

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onLoadDiets(LoadDiets event, Emitter<DietState> emit) async {
    emit(state.copyWith(isSyncing: true, syncFailed: false));
    await _performSync(emit);
  }

  Future<void> _onSyncWithCloud(SyncWithCloud event, Emitter<DietState> emit) async {
    emit(state.copyWith(isSyncing: true, syncFailed: false));
    await _performSync(emit);
  }

  Future<void> _onSetDefaultDiet(SetDefaultDiet event, Emitter<DietState> emit) async {
    final updatedDiets = state.diets.map((diet) {
      return diet.copyWith(isDefault: diet.id == event.id);
    }).toList();
    emit(state.copyWith(diets: updatedDiets, defaultDietId: event.id));
    _triggerBackgroundUpsert(updatedDiets);
  }

  Future<void> _onAddDiet(AddDiet event, Emitter<DietState> emit) async {
    final newDiet = DietPlan(
      name: event.name,
      isDefault: state.diets.isEmpty,
      meals: [],
    );
    
    final updatedDiets = List<DietPlan>.from(state.diets)..add(newDiet);
    final defaultId = newDiet.isDefault ? newDiet.id : state.defaultDietId;
    
    emit(state.copyWith(diets: updatedDiets, defaultDietId: defaultId));
    _triggerBackgroundUpsert(updatedDiets);
  }

  Future<void> _onUpdateDiet(UpdateDiet event, Emitter<DietState> emit) async {
    final updatedDiet = event.diet.copyWith(updatedAt: DateTime.now());
    final updatedDiets = state.diets.map((d) => d.id == updatedDiet.id ? updatedDiet : d).toList();
    
    emit(state.copyWith(diets: updatedDiets));
    _triggerBackgroundSingleUpsert(updatedDiet);
  }

  Future<void> _onDeleteDiet(DeleteDiet event, Emitter<DietState> emit) async {
    final updatedDiets = state.diets.where((d) => d.id != event.id).toList();
    final defaultId = state.defaultDietId == event.id 
        ? (updatedDiets.isNotEmpty ? updatedDiets.first.id : null)
        : state.defaultDietId;

    emit(state.copyWith(
      diets: updatedDiets, 
      defaultDietId: defaultId,
    ));

    final client = _supabaseClient;
    if (client != null) {
      client.from('diet_plans').delete().eq('id', event.id).then((_) {}).catchError((_) {});
    }
  }

  // --- Library Handlers ---
  void _onAddLibraryMeal(AddLibraryMeal event, Emitter<DietState> emit) {
    final updated = List<Meal>.from(state.libraryMeals)..add(event.meal);
    emit(state.copyWith(libraryMeals: updated));
  }

  void _onUpdateLibraryMeal(UpdateLibraryMeal event, Emitter<DietState> emit) {
    final updated = state.libraryMeals.map((m) => m.id == event.meal.id ? event.meal : m).toList();
    emit(state.copyWith(libraryMeals: updated));
  }

  void _onDeleteLibraryMeal(DeleteLibraryMeal event, Emitter<DietState> emit) {
    final updated = state.libraryMeals.where((m) => m.id != event.id).toList();
    emit(state.copyWith(libraryMeals: updated));
  }

  void _onReorderLibraryMeals(ReorderLibraryMeals event, Emitter<DietState> emit) {
    // Filter out meals of specific category
    final categoryMeals = state.libraryMeals.where((m) => m.category == event.category).toList();
    categoryMeals.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    int newIndex = event.newIndex;
    if (event.oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = categoryMeals.removeAt(event.oldIndex);
    categoryMeals.insert(newIndex, item);

    // Reassign sort orders
    for (int i = 0; i < categoryMeals.length; i++) {
      categoryMeals[i] = categoryMeals[i].copyWith(sortOrder: i);
    }

    // Merge back into total library meals
    final remainingMeals = state.libraryMeals.where((m) => m.category != event.category).toList();
    final finalMeals = [...remainingMeals, ...categoryMeals];

    emit(state.copyWith(libraryMeals: finalMeals));
  }

  // Helper: Merges remote and local state
  Future<void> _performSync(Emitter<DietState> emit) async {
    final client = _supabaseClient;
    if (client == null) {
      emit(state.copyWith(isSyncing: false, syncFailed: true));
      return;
    }

    try {
      final response = await client.from('diet_plans').select();
      final remoteDiets = (response as List<dynamic>)
          .map((json) => DietPlan.fromJson(json as Map<String, dynamic>))
          .toList();

      final mergedDiets = <String, DietPlan>{};
      for (var d in state.diets) {
        mergedDiets[d.id] = d;
      }

      List<DietPlan> toUpload = [];
      for (var remote in remoteDiets) {
        final local = mergedDiets[remote.id];
        if (local == null) {
          mergedDiets[remote.id] = remote;
        } else {
          if (remote.updatedAt.isAfter(local.updatedAt)) {
            mergedDiets[remote.id] = remote;
          } else if (local.updatedAt.isAfter(remote.updatedAt)) {
            toUpload.add(local);
          }
        }
      }

      for (var local in state.diets) {
        if (!remoteDiets.any((r) => r.id == local.id)) {
          toUpload.add(local);
        }
      }

      final finalDiets = mergedDiets.values.toList();
      String? defaultId = state.defaultDietId;
      if (defaultId == null || !finalDiets.any((d) => d.id == defaultId)) {
        final defPlan = finalDiets.firstWhere((d) => d.isDefault, orElse: () => finalDiets.isNotEmpty ? finalDiets.first : DietPlan(name: '', meals: []));
        if (defPlan.name.isNotEmpty) {
          defaultId = defPlan.id;
        }
      }

      emit(state.copyWith(
        diets: finalDiets,
        defaultDietId: defaultId,
        isSyncing: toUpload.isNotEmpty,
        syncFailed: false,
      ));

      if (toUpload.isNotEmpty) {
        for (var diet in toUpload) {
          await client.from('diet_plans').upsert(diet.toJson());
        }
      }

      emit(state.copyWith(isSyncing: false, syncFailed: false));
    } catch (e) {
      emit(state.copyWith(isSyncing: false, syncFailed: true));
    }
  }

  void _triggerBackgroundUpsert(List<DietPlan> diets) async {
    final client = _supabaseClient;
    if (client == null) return;
    try {
      for (var diet in diets) {
        await client.from('diet_plans').upsert(diet.toJson());
      }
    } catch (_) {}
  }

  void _triggerBackgroundSingleUpsert(DietPlan diet) async {
    final client = _supabaseClient;
    if (client == null) return;
    try {
      await client.from('diet_plans').upsert(diet.toJson());
    } catch (_) {}
  }

  // --- HydratedBloc Implementation ---
  @override
  DietState? fromJson(Map<String, dynamic> json) => DietState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(DietState state) => state.toJson();
}
