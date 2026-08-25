import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/diet_bloc.dart';
import '../../core/theme.dart';
import '../../models/diet_plan.dart';

class MealLibraryScreen extends StatefulWidget {
  final Function(Meal)? onMealSelected; // If null, we are in database edit mode

  const MealLibraryScreen({super.key, this.onMealSelected});

  @override
  State<MealLibraryScreen> createState() => _MealLibraryScreenState();
}

class _MealLibraryScreenState extends State<MealLibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _mealNameController = TextEditingController();

  // Temporary controllers for inline ingredient creation
  final Map<String, TextEditingController> _ingNameControllers = {};
  final Map<String, TextEditingController> _ingQtyControllers = {};
  final Map<String, String> _ingUnits = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mealNameController.dispose();
    for (var controller in _ingNameControllers.values) {
      controller.dispose();
    }
    for (var controller in _ingQtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getCategoryFromIndex(int index) {
    switch (index) {
      case 0:
        return 'Breakfast';
      case 1:
        return 'Lunch';
      case 2:
        return 'Dinner';
      default:
        return 'Breakfast';
    }
  }

  void _showAddMealModal(String category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Новое блюдо в библиотеку',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _mealNameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Название блюда',
                  hintText: 'например, Греческий салат',
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final name = _mealNameController.text.trim();
                  if (name.isNotEmpty) {
                    final newMeal = Meal(
                      name: name,
                      category: category,
                      time: category == 'Breakfast'
                          ? '08:00'
                          : category == 'Lunch'
                              ? '13:00'
                              : '19:00',
                      date: '',
                      sortOrder: 100, // Reorderable handles it
                      ingredients: [],
                    );
                    context.read<DietBloc>().add(AddLibraryMeal(newMeal));
                    _mealNameController.clear();
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Создать', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryTab(String category, List<Meal> libraryMeals) {
    final meals = libraryMeals.where((m) => m.category == category).toList();
    meals.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (meals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.blur_on, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('Нет блюд в этой категории', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddMealModal(category),
              icon: const Icon(Icons.add),
              label: const Text('Добавить блюдо'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.background,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: meals.length,
      onReorder: (oldIndex, newIndex) {
        context.read<DietBloc>().add(ReorderLibraryMeals(category, oldIndex, newIndex));
      },
      itemBuilder: (context, index) {
        final meal = meals[index];
        final key = ValueKey(meal.id);

        // Initialize inline form states if needed
        if (!_ingNameControllers.containsKey(meal.id)) {
          _ingNameControllers[meal.id] = TextEditingController();
          _ingQtyControllers[meal.id] = TextEditingController();
          _ingUnits[meal.id] = 'gr';
        }

        return Card(
          key: key,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            key: PageStorageKey(meal.id),
            title: Text(
              meal.name,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              '${meal.ingredients.length} ингредиентов',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onMealSelected != null)
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppTheme.accent, size: 28),
                    onPressed: () {
                      widget.onMealSelected!(meal);
                      Navigator.pop(context);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                  onPressed: () {
                    context.read<DietBloc>().add(DeleteLibraryMeal(meal.id));
                  },
                ),
              ],
            ),
            children: [
              PageStorage(
                bucket: PageStorageBucket(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(color: Color(0xFF334155)),
                      const SizedBox(height: 8),
                      Text(
                        'Состав блюда:',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.accentMuted),
                      ),
                      const SizedBox(height: 8),
                      if (meal.ingredients.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Ингредиенты не добавлены',
                            style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        ...meal.ingredients.map((ing) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${ing.name} — ${ing.quantity % 1 == 0 ? ing.quantity.toInt() : ing.quantity} ${ing.unit}',
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                                ),
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 20),
                                  onPressed: () {
                                    final updatedIngredients = List<Ingredient>.from(meal.ingredients)..remove(ing);
                                    context.read<DietBloc>().add(UpdateLibraryMeal(meal.copyWith(ingredients: updatedIngredients)));
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                      const Text(
                        'Добавить ингредиент:',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Inline form to add ingredient
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              key: ValueKey('ing_name_${meal.id}'),
                              controller: _ingNameControllers[meal.id],
                              decoration: const InputDecoration(
                                hintText: 'Продукт',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              key: ValueKey('ing_qty_${meal.id}'),
                              controller: _ingQtyControllers[meal.id],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: 'Кол-во',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('ing_unit_${meal.id}'),
                              initialValue: _ingUnits[meal.id],
                              dropdownColor: AppTheme.cardBg,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                              items: const [
                                DropdownMenuItem(value: 'gr', child: Text('гр')),
                                DropdownMenuItem(value: 'pcs', child: Text('шт')),
                                DropdownMenuItem(value: 'ml', child: Text('мл')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _ingUnits[meal.id] = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          final name = _ingNameControllers[meal.id]?.text.trim() ?? '';
                          final qtyStr = _ingQtyControllers[meal.id]?.text.trim() ?? '';
                          final qty = double.tryParse(qtyStr) ?? 0.0;
                          final unit = _ingUnits[meal.id] ?? 'gr';

                          if (name.isNotEmpty && qty > 0) {
                            final newIng = Ingredient(name: name, quantity: qty, unit: unit);
                            final updatedIngredients = List<Ingredient>.from(meal.ingredients)..add(newIng);
                            context.read<DietBloc>().add(
                                  UpdateLibraryMeal(meal.copyWith(ingredients: updatedIngredients)),
                                );

                            _ingNameControllers[meal.id]?.clear();
                            _ingQtyControllers[meal.id]?.clear();
                          }
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Добавить продукт'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentMuted,
                          foregroundColor: AppTheme.background,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onMealSelected != null ? 'Выберите блюдо' : 'Библиотека блюд'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Завтрак'),
            Tab(text: 'Ланч'),
            Tab(text: 'Обед / Ужин'),
          ],
        ),
      ),
      body: BlocBuilder<DietBloc, DietState>(
        builder: (context, state) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryTab('Breakfast', state.libraryMeals),
              _buildCategoryTab('Lunch', state.libraryMeals),
              _buildCategoryTab('Dinner', state.libraryMeals),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final activeCategory = _getCategoryFromIndex(_tabController.index);
          _showAddMealModal(activeCategory);
        },
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.background,
        child: const Icon(Icons.add),
      ),
    );
  }
}
