import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../blocs/diet_bloc.dart';
import '../../core/theme.dart';
import '../../models/meal.dart';

class MealsLibraryScreen extends StatefulWidget {
  final String? filterCategory; // If specified, filters meals to this category for picking
  final Function(String)? onMealPicked; // If specified, tapping a meal returns its ID
  final bool isTab; // If true, hides the AppBar (rendered as a bottom navigation tab)

  const MealsLibraryScreen({
    super.key,
    this.filterCategory,
    this.onMealPicked,
    this.isTab = false,
  });

  @override
  State<MealsLibraryScreen> createState() => _MealsLibraryScreenState();
}

class _MealsLibraryScreenState extends State<MealsLibraryScreen> {
  String _activeFilter = 'All';
  final List<String> _filters = ['All', 'Breakfast', 'Lunch', 'Dinner', 'Snacks'];

  @override
  void initState() {
    super.initState();
    if (widget.filterCategory != null) {
      _activeFilter = widget.filterCategory == 'Snack' ? 'Snacks' : widget.filterCategory!;
    }
  }

  void _showAddMealModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _AddMealModalSheet(filterCategory: widget.filterCategory);
      },
    );
  }

  Widget _buildFilterChips() {
    // Hide filter bar if we are picking for a specific slot category
    if (widget.filterCategory != null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _filters.map((filterName) {
          final isSelected = _activeFilter == filterName;

          return ChoiceChip(
            label: Text(filterName),
            selected: isSelected,
            selectedColor: AppTheme.accent.withValues(alpha: 0.15),
            checkmarkColor: AppTheme.accent,
            labelStyle: TextStyle(
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _activeFilter = filterName;
                });
              }
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPickerMode = widget.onMealPicked != null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: widget.isTab
          ? null
          : AppBar(
              title: Text(isPickerMode ? 'Select ${widget.filterCategory}' : 'Meals Library'),
              backgroundColor: AppTheme.background,
              elevation: 0,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header title if in tab mode
          if (widget.isTab) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
              child: Text(
                'Meals Library',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
              ),
            ),
          ],

          // Dynamic category filters (in compact Wrap)
          _buildFilterChips(),

          // Display list
          Expanded(
            child: BlocBuilder<DietBloc, DietState>(
              builder: (context, state) {
                // Filter the meals dynamically
                final filteredMeals = state.mealsLibrary.where((m) {
                  if (widget.filterCategory != null) {
                    final targetCat = widget.filterCategory == 'Snacks' ? 'Snack' : widget.filterCategory;
                    return m.category == targetCat;
                  }
                  if (_activeFilter == 'All') return true;
                  final targetFilter = _activeFilter == 'Snacks' ? 'Snack' : _activeFilter;
                  return m.category == targetFilter;
                }).toList();

                if (filteredMeals.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.flatware_outlined,
                            size: 72,
                            color: AppTheme.textSecondary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No meals found',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.filterCategory != null
                                ? 'Add a custom dish to the ${widget.filterCategory} library.'
                                : 'Try changing the active category filter.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredMeals.length,
                  itemBuilder: (context, index) {
                    final meal = filteredMeals[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: AppTheme.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFF334155), width: 1),
                      ),
                      child: InkWell(
                        onTap: isPickerMode
                            ? () {
                                widget.onMealPicked!(meal.id);
                                Navigator.pop(context);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header info
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      meal.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      meal.category,
                                      style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Ingredients Chips Wrap
                              if (meal.ingredients.isNotEmpty) ...[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: meal.ingredients.map((ing) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF334155)),
                                      ),
                                      child: Text(
                                        ing,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Actions Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isPickerMode) ...[
                                    TextButton.icon(
                                      onPressed: () {
                                        widget.onMealPicked!(meal.id);
                                        Navigator.pop(context);
                                      },
                                      icon: const Icon(Icons.check_circle_outline, color: AppTheme.accent, size: 18),
                                      label: const Text(
                                        'Select',
                                        style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            backgroundColor: AppTheme.cardBg,
                                            title: const Text('Delete Dish'),
                                            content: Text('Are you sure you want to delete "${meal.name}"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text(
                                                  'Cancel',
                                                  style: TextStyle(color: AppTheme.textSecondary),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  context.read<DietBloc>().add(DeleteMealFromLibrary(meal.id));
                                                  Navigator.pop(context);
                                                },
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(color: AppTheme.error),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMealModal(context),
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.background,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddMealModalSheet extends StatefulWidget {
  final String? filterCategory;
  const _AddMealModalSheet({this.filterCategory});

  @override
  State<_AddMealModalSheet> createState() => _AddMealModalSheetState();
}

class _AddMealModalSheetState extends State<_AddMealModalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _tagInputController;
  late final FocusNode _tagFocusNode;
  final List<String> _tempIngredients = [];
  late String _formCategory;

  final List<String> _categories = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _tagInputController = TextEditingController();
    _tagFocusNode = FocusNode();
    _formCategory = widget.filterCategory == 'Snacks'
        ? 'Snack'
        : (widget.filterCategory ?? 'Breakfast');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  void _addIngredientTag(String input) {
    final trimmed = input.trim();
    if (trimmed.isNotEmpty && !_tempIngredients.contains(trimmed)) {
      setState(() {
        _tempIngredients.add(trimmed);
      });
    }
    _tagInputController.clear();
    _tagFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add New Dish',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 20),

                // Dish Name Input
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Dish Name',
                    hintText: 'e.g., Spaghetti Carbonara',
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the dish name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category Selector Label
                const Text(
                  'Category',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Category ChoiceChips Wrap
                Wrap(
                  spacing: 8,
                  children: _categories.map((cat) {
                    final isSelected = _formCategory == cat;
                    final displayLabel = cat == 'Snack' ? 'Snack' : cat;
                    return ChoiceChip(
                      label: Text(displayLabel),
                      selected: isSelected,
                      selectedColor: AppTheme.accent.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.accent,
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _formCategory = cat;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                 Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tagInputController,
                        focusNode: _tagFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'Add Ingredients',
                          hintText: 'Type and press comma/enter',
                        ),
                        style: const TextStyle(color: AppTheme.textPrimary),
                        onChanged: (value) {
                          if (value.contains(',')) {
                            final parts = value.split(',');
                            for (var part in parts) {
                              final trimmed = part.trim();
                              if (trimmed.isNotEmpty && !_tempIngredients.contains(trimmed)) {
                                setState(() {
                                  _tempIngredients.add(trimmed);
                                });
                              }
                            }
                            _tagInputController.clear();
                            _tagFocusNode.requestFocus();
                          }
                        },
                        onFieldSubmitted: (value) {
                          _addIngredientTag(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        _addIngredientTag(_tagInputController.text);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.background,
                        padding: const EdgeInsets.all(12),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.add, size: 24),
                    ),
                  ],
                ),

                // Ingredient Tags Wrap
                if (_tempIngredients.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tempIngredients.map((ing) {
                      return InputChip(
                        label: Text(ing),
                        backgroundColor: const Color(0xFF0F172A),
                        deleteIcon: const Icon(Icons.cancel, size: 16, color: AppTheme.textSecondary),
                        labelStyle: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFF334155)),
                        ),
                        onDeleted: () {
                          setState(() {
                            _tempIngredients.remove(ing);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 28),

                // Submit Button
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final newMeal = Meal(
                        id: const Uuid().v4(),
                        name: _nameController.text.trim(),
                        category: _formCategory,
                        ingredients: _tempIngredients,
                      );

                      context.read<DietBloc>().add(AddMealToLibrary(newMeal));
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
                  child: const Text(
                    'Save Dish',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
