import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../blocs/diet_bloc.dart';
import '../../core/theme.dart';
import '../../models/meal.dart';
import '../../models/meal_slot_config.dart';
import '../../services/food_analysis_service.dart';

class MealsLibraryScreen extends StatefulWidget {
  final String? initialCategory; // If specified, pre-selects this category filter
  final String? filterCategory; // Backwards-compatible alias for initialCategory
  final String? targetSlotId; // If picking for a specific slot, the slot ID
  final String? targetSlotName; // If picking for a specific slot, the slot name
  final Function(String)? onMealPicked; // If specified, tapping a meal returns its ID
  final bool isTab; // If true, hides the AppBar (rendered as a bottom navigation tab)

  const MealsLibraryScreen({
    super.key,
    this.initialCategory,
    this.filterCategory,
    this.targetSlotId,
    this.targetSlotName,
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
    final startCat = widget.initialCategory ?? widget.filterCategory;
    if (startCat != null) {
      if (startCat.toLowerCase() == 'snack' || startCat.toLowerCase() == 'snacks') {
        _activeFilter = 'Snacks';
      } else {
        final match = _filters.firstWhere(
          (f) => f.toLowerCase() == startCat.toLowerCase(),
          orElse: () => startCat,
        );
        _activeFilter = match;
      }
    }
  }

  void _showAddMealModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: _AddMealModalSheet(
            filterCategory: _activeFilter != 'All'
                ? _activeFilter
                : (widget.initialCategory ?? widget.filterCategory),
          ),
        );
      },
    );
  }

  void _showEditMealModal(BuildContext context, Meal meal) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: _EditMealDialog(meal: meal),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _filters.map((filterName) {
            final isSelected = _activeFilter == filterName;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
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
              ),
            );
          }).toList(),
        ),
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
              title: Text(
                isPickerMode
                    ? (widget.targetSlotName != null ? 'Add to ${widget.targetSlotName}' : 'Select Meal')
                    : 'Meals Library',
              ),
              backgroundColor: AppTheme.background,
              elevation: 0,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: TextButton.icon(
                    onPressed: () => _showAddMealModal(context),
                    icon: const Icon(Icons.add, color: AppTheme.accent, size: 18),
                    label: const Text(
                      '+ New Meal',
                      style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header title if in tab mode
          if (widget.isTab) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Meals Library',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddMealModal(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('+ New Meal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Dynamic category filters (in compact Wrap)
          _buildFilterChips(),

          // Display list
          Expanded(
            child: BlocBuilder<DietBloc, DietState>(
              builder: (context, state) {
                // Filter the meals dynamically by active filter
                final filteredMeals = state.mealsLibrary.where((m) {
                  if (_activeFilter == 'All') return true;
                  final targetFilter = _activeFilter == 'Snacks' ? 'Snack' : _activeFilter;
                  return m.category.toLowerCase() == targetFilter.toLowerCase();
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
                            _activeFilter != 'All'
                                ? 'No meals found in "$_activeFilter" category.\nTry selecting another category or add a new meal.'
                                : 'Try adding a new meal to your library.',
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

                              // Nutrition summary chips
                              if ((meal.calories ?? 0) > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF334155)),
                                  ),
                                  child: Wrap(
                                    spacing: 10,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '${meal.calories!.round()} kcal',
                                        style: const TextStyle(
                                          color: Color(0xFFF59E0B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'P: ${(meal.protein ?? 0).toStringAsFixed(1)}g',
                                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
                                      ),
                                      Text(
                                        'F: ${(meal.fats ?? 0).toStringAsFixed(1)}g',
                                        style: const TextStyle(color: Color(0xFFEAB308), fontSize: 11),
                                      ),
                                      Text(
                                        'C: ${(meal.carbs ?? 0).toStringAsFixed(1)}g',
                                        style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11),
                                      ),
                                      if ((meal.fiber ?? 0) > 0)
                                        Text(
                                          'Fiber: ${meal.fiber!.toStringAsFixed(1)}g',
                                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 11),
                                        ),
                                    ],
                                  ),
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
                                  ] else ...[
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddToTodayDialog(context, meal),
                                      icon: const Icon(Icons.today_outlined, size: 14),
                                      label: const Text('Add to Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
                                        foregroundColor: AppTheme.accent,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppTheme.accent),
                                    tooltip: 'Edit meal',
                                    onPressed: () => _showEditMealModal(context, meal),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                    tooltip: 'Delete dish',
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
    );
  }

  void _showAddToTodayDialog(BuildContext context, Meal meal) {
    final state = context.read<DietBloc>().state;
    final slots = state.mealSlots;
    if (slots.isEmpty) return;

    double multiplier = 1.0;
    final multipliers = [0.5, 1.0, 1.5, 2.0];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final baseCal = meal.calories ?? 0.0;
          final baseP = meal.protein ?? 0.0;
          final baseF = meal.fats ?? 0.0;
          final baseC = meal.carbs ?? 0.0;
          final baseFiber = meal.fiber ?? 0.0;

          final scaledCal = baseCal * multiplier;
          final scaledP = baseP * multiplier;
          final scaledF = baseF * multiplier;
          final scaledC = baseC * multiplier;
          final scaledFiber = baseFiber * multiplier;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.today_outlined, color: AppTheme.accent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Log to Today',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Meal Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.restaurant_menu, color: AppTheme.accent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                meal.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                meal.category,
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (baseCal > 0 || baseP > 0 || baseF > 0 || baseC > 0) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                '${scaledCal.toStringAsFixed(0)} kcal',
                                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text('P: ${scaledP.toStringAsFixed(1)}g', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                              Text('F: ${scaledF.toStringAsFixed(1)}g', style: const TextStyle(color: Color(0xFFEAB308), fontSize: 12)),
                              Text('C: ${scaledC.toStringAsFixed(1)}g', style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12)),
                              if (scaledFiber > 0)
                                Text('Fiber: ${scaledFiber.toStringAsFixed(1)}g', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Servings Multiplier Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Serving Size:',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: multipliers.map((m) {
                          final isSelected = (multiplier == m);
                          final label = '${m == m.roundToDouble() ? m.toInt() : m}x';

                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  multiplier = m;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.accent : const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.accent : const Color(0xFF334155),
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected ? AppTheme.background : AppTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Select Target Slot:',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Slots list
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Builder(
                        builder: (context) {
                          // Prioritize target slot, then matching category slots
                          final sortedSlots = List<MealSlotConfig>.from(slots);
                          sortedSlots.sort((a, b) {
                            if (widget.targetSlotId != null) {
                              if (a.id == widget.targetSlotId) return -1;
                              if (b.id == widget.targetSlotId) return 1;
                            }
                            final targetSlotName = widget.targetSlotName ?? widget.initialCategory ?? widget.filterCategory;
                            final aMatchesTarget = targetSlotName != null &&
                                (a.name.toLowerCase().contains(targetSlotName.toLowerCase()) ||
                                 targetSlotName.toLowerCase().contains(a.name.toLowerCase()));
                            final bMatchesTarget = targetSlotName != null &&
                                (b.name.toLowerCase().contains(targetSlotName.toLowerCase()) ||
                                 targetSlotName.toLowerCase().contains(b.name.toLowerCase()));
                            if (aMatchesTarget && !bMatchesTarget) return -1;
                            if (!aMatchesTarget && bMatchesTarget) return 1;

                            final aMatchesMeal = a.name.toLowerCase().contains(meal.category.toLowerCase()) ||
                                meal.category.toLowerCase().contains(a.name.toLowerCase());
                            final bMatchesMeal = b.name.toLowerCase().contains(meal.category.toLowerCase()) ||
                                meal.category.toLowerCase().contains(b.name.toLowerCase());
                            if (aMatchesMeal && !bMatchesMeal) return -1;
                            if (!aMatchesMeal && bMatchesMeal) return 1;

                            return a.orderIndex.compareTo(b.orderIndex);
                          });

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: sortedSlots.map((slot) {
                              final isTargetSlot = (widget.targetSlotId != null && slot.id == widget.targetSlotId) ||
                                  (widget.targetSlotName != null &&
                                      (slot.name.toLowerCase().contains(widget.targetSlotName!.toLowerCase()) ||
                                       widget.targetSlotName!.toLowerCase().contains(slot.name.toLowerCase())));
                              final isMatchingCategory = isTargetSlot ||
                                  slot.name.toLowerCase().contains(meal.category.toLowerCase()) ||
                                  meal.category.toLowerCase().contains(slot.name.toLowerCase());

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      final today = DateTime.now();

                                      // Schedule meal with multiplier in slot plan & log actual macros
                                      context.read<DietBloc>().add(
                                            ScheduleMealToSlot(
                                              date: today,
                                              slotId: slot.id,
                                              mealId: meal.id,
                                              multiplier: multiplier,
                                            ),
                                          );

                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✓ Logged "${meal.name}" (${multiplier == multiplier.roundToDouble() ? multiplier.toInt() : multiplier}x) to ${slot.name} for today!'),
                                          backgroundColor: const Color(0xFF10B981),
                                        ),
                                      );
                                      if (widget.onMealPicked != null) {
                                        Navigator.pop(context);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isMatchingCategory
                                            ? AppTheme.accent.withValues(alpha: 0.1)
                                            : const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isMatchingCategory
                                              ? AppTheme.accent.withValues(alpha: 0.4)
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                _getSlotEmoji(slot.name),
                                                style: const TextStyle(fontSize: 18),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                slot.name,
                                                style: TextStyle(
                                                  color: isMatchingCategory ? AppTheme.accent : AppTheme.textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 14,
                                            color: isMatchingCategory ? AppTheme.accent : AppTheme.textSecondary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getSlotEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('breakfast')) return '🍳';
    if (lower.contains('lunch')) return '🥗';
    if (lower.contains('dinner')) return '🍲';
    if (lower.contains('snack')) return '🍎';
    return '🍽️';
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
  late final TextEditingController _descriptionController;
  late String _formCategory;
  bool _isCalculating = false;

  final List<String> _categories = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _formCategory = widget.filterCategory == 'Snacks'
        ? 'Snack'
        : (widget.filterCategory ?? 'Breakfast');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _calculateAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    setState(() {
      _isCalculating = true;
    });

    try {
      final rawParts = description
          .split(RegExp(r'[,;\n\r\+]|\bи\b|\band\b', caseSensitive: false))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final result = await FoodAnalysisService().estimateNutritionalValues(
        mealName: name,
        ingredients: rawParts.isNotEmpty ? rawParts : [description],
      );

      final List<String> ingredientsList = [];
      if (result.items.isNotEmpty) {
        for (final item in result.items) {
          if (item.weight != null && item.weight!.isNotEmpty) {
            ingredientsList.add('${item.name} (${item.weight})');
          } else {
            ingredientsList.add(item.name);
          }
        }
      } else if (rawParts.isNotEmpty) {
        ingredientsList.addAll(rawParts);
      } else {
        ingredientsList.add(name);
      }

      final newMeal = Meal(
        id: const Uuid().v4(),
        name: name,
        category: _formCategory,
        ingredients: ingredientsList,
        calories: result.calories,
        protein: result.protein,
        fats: result.fats,
        carbs: result.carbs,
        fiber: result.fiber,
        aiBreakdown: {
          'items': result.items.map((i) => i.toMap()).toList(),
          if (result.cleanedDescription != null) 'cleaned_description': result.cleanedDescription,
        },
        defaultServings: 1.0,
      );

      if (mounted) {
        context.read<DietBloc>().add(AddMealToLibrary(newMeal));
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Saved "$name" (${result.calories.round()} kcal • P: ${result.protein.toStringAsFixed(1)}g F: ${result.fats.toStringAsFixed(1)}g C: ${result.carbs.toStringAsFixed(1)}g)',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Local Heuristic Fallback
      final localResult = LocalFoodParser.parse(
        mealName: name,
        ingredients: [description],
      );

      final newMeal = Meal(
        id: const Uuid().v4(),
        name: name,
        category: _formCategory,
        ingredients: localResult.items
            .map((i) => i.weight != null ? '${i.name} (${i.weight})' : i.name)
            .toList(),
        calories: localResult.calories,
        protein: localResult.protein,
        fats: localResult.fats,
        carbs: localResult.carbs,
        fiber: localResult.fiber,
        aiBreakdown: {
          'items': localResult.items.map((i) => i.toMap()).toList(),
          if (localResult.cleanedDescription != null) 'cleaned_description': localResult.cleanedDescription,
        },
        defaultServings: 1.0,
      );

      if (mounted) {
        context.read<DietBloc>().add(AddMealToLibrary(newMeal));
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Saved "$name" (~${localResult.calories.round()} kcal)'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCalculating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 460 ? 440.0 : (screenWidth * 0.94);

    return Container(
      width: dialogWidth,
      constraints: BoxConstraints(
        maxWidth: 440,
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restaurant_menu, color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Create New Meal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Field 1: Meal Name Input
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Meal Name *',
                        hintText: 'e.g. Фирменный салат с тунцом',
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the meal name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Field 2: Category Selector
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
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: AppTheme.accent.withValues(alpha: 0.2),
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

                    // Field 3: Large Multiline Ingredients / Description
                    const Text(
                      'Ingredients / Description *',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Например: банка тунца 130г, 1 огурец, помидор 120г, вареное яйцо, салат айсберг 100г',
                        alignLabelWithHint: true,
                        contentPadding: EdgeInsets.all(14),
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter ingredients or description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Calculate & Save Button
                    ElevatedButton.icon(
                      onPressed: _isCalculating ? null : _calculateAndSave,
                      icon: _isCalculating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 20),
                      label: Text(
                        _isCalculating ? 'Calculating & Saving...' : 'Calculate & Save',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableIngredient {
  final TextEditingController nameController;
  final TextEditingController weightController;
  double calories;
  double protein;
  double fats;
  double carbs;
  double fiber;

  _EditableIngredient({
    required String name,
    required String weight,
    this.calories = 0.0,
    this.protein = 0.0,
    this.fats = 0.0,
    this.carbs = 0.0,
    this.fiber = 0.0,
  })  : nameController = TextEditingController(text: name),
        weightController = TextEditingController(text: weight);

  void dispose() {
    nameController.dispose();
    weightController.dispose();
  }
}

class _EditMealDialog extends StatefulWidget {
  final Meal meal;
  const _EditMealDialog({required this.meal});

  @override
  State<_EditMealDialog> createState() => _EditMealDialogState();
}

class _EditMealDialogState extends State<_EditMealDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _category;
  final List<String> _categories = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  final List<_EditableIngredient> _ingredients = [];

  double _totalCalories = 0.0;
  double _totalProtein = 0.0;
  double _totalFats = 0.0;
  double _totalCarbs = 0.0;
  double _totalFiber = 0.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.meal.name);
    _category = widget.meal.category;

    _initializeIngredients();
    _recalculateTotals();
  }

  void _initializeIngredients() {
    final dynamic aiBreakdown = widget.meal.aiBreakdown;
    List<dynamic>? items;
    if (aiBreakdown is Map && aiBreakdown['items'] is List) {
      items = aiBreakdown['items'] as List<dynamic>;
    } else if (aiBreakdown is List) {
      items = aiBreakdown;
    }

    if (items != null && items.isNotEmpty) {
      for (final raw in items) {
        if (raw is Map) {
          final name = raw['name']?.toString() ?? 'Ingredient';
          final weight = raw['weight']?.toString() ??
              (raw['weight_g'] != null ? '${raw['weight_g']}g' : '100g');
          final cal = (raw['calories'] as num?)?.toDouble() ?? 0.0;
          final p = (raw['protein'] as num?)?.toDouble() ?? 0.0;
          final f = (raw['fats'] as num?)?.toDouble() ?? 0.0;
          final c = (raw['carbs'] as num?)?.toDouble() ?? 0.0;
          final fib = (raw['fiber'] as num?)?.toDouble() ?? 0.0;

          final item = _EditableIngredient(
            name: name,
            weight: weight,
            calories: cal,
            protein: p,
            fats: f,
            carbs: c,
            fiber: fib,
          );
          if (item.calories == 0) {
            _computeItemMacros(item);
          }
          _ingredients.add(item);
        }
      }
    }

    if (_ingredients.isEmpty && widget.meal.ingredients.isNotEmpty) {
      for (final ingStr in widget.meal.ingredients) {
        final parsedInfo = _parseIngredientString(ingStr);
        final item = _EditableIngredient(
          name: parsedInfo['name']!,
          weight: parsedInfo['weight']!,
        );
        _computeItemMacros(item);
        _ingredients.add(item);
      }
    }

    if (_ingredients.isEmpty) {
      final item = _EditableIngredient(
        name: widget.meal.name,
        weight: '100g',
        calories: widget.meal.calories ?? 0.0,
        protein: widget.meal.protein ?? 0.0,
        fats: widget.meal.fats ?? 0.0,
        carbs: widget.meal.carbs ?? 0.0,
        fiber: widget.meal.fiber ?? 0.0,
      );
      if (item.calories == 0) {
        _computeItemMacros(item);
      }
      _ingredients.add(item);
    }
  }

  Map<String, String> _parseIngredientString(String raw) {
    final match = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(raw.trim());
    if (match != null) {
      return {
        'name': match.group(1)?.trim() ?? raw,
        'weight': match.group(2)?.trim() ?? '100g',
      };
    }
    final trailingMatch = RegExp(
      r'^(.*?)\s+(\d+(?:\.\d+)?\s*(?:g|г|ml|мл|oz|kg|кг|tbsp|tsp|cup|cups)?)$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (trailingMatch != null) {
      return {
        'name': trailingMatch.group(1)?.trim() ?? raw,
        'weight': trailingMatch.group(2)?.trim() ?? '100g',
      };
    }
    return {
      'name': raw.trim(),
      'weight': '100g',
    };
  }

  void _computeItemMacros(_EditableIngredient item) {
    final name = item.nameController.text.trim();
    final weight = item.weightController.text.trim();
    if (name.isEmpty) {
      item.calories = 0.0;
      item.protein = 0.0;
      item.fats = 0.0;
      item.carbs = 0.0;
      item.fiber = 0.0;
      return;
    }

    final query = weight.isNotEmpty ? '$name $weight' : name;
    final res = LocalFoodParser.parse(mealName: name, ingredients: [query]);
    item.calories = res.calories;
    item.protein = res.protein;
    item.fats = res.fats;
    item.carbs = res.carbs;
    item.fiber = res.fiber;
  }

  void _recalculateTotals() {
    double cal = 0.0;
    double p = 0.0;
    double f = 0.0;
    double c = 0.0;
    double fib = 0.0;

    for (final item in _ingredients) {
      cal += item.calories;
      p += item.protein;
      f += item.fats;
      c += item.carbs;
      fib += item.fiber;
    }

    setState(() {
      _totalCalories = cal;
      _totalProtein = p;
      _totalFats = f;
      _totalCarbs = c;
      _totalFiber = fib;
    });
  }

  void _onIngredientChanged(_EditableIngredient item) {
    _computeItemMacros(item);
    _recalculateTotals();
  }

  void _addIngredient() {
    final newItem = _EditableIngredient(name: '', weight: '100g');
    setState(() {
      _ingredients.add(newItem);
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      final removed = _ingredients.removeAt(index);
      removed.dispose();
      _recalculateTotals();
    });
  }

  void _saveChanges() {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please have at least one ingredient'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final mealName = _nameController.text.trim();
    final List<String> updatedIngredients = [];
    final List<Map<String, dynamic>> breakdownItems = [];

    for (final item in _ingredients) {
      final name = item.nameController.text.trim();
      final weight = item.weightController.text.trim();
      if (name.isNotEmpty) {
        final display = weight.isNotEmpty ? '$name ($weight)' : name;
        updatedIngredients.add(display);
        breakdownItems.add({
          'name': name,
          'weight': weight,
          'calories': item.calories,
          'protein': item.protein,
          'fats': item.fats,
          'carbs': item.carbs,
          'fiber': item.fiber,
        });
      }
    }

    if (updatedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid ingredient names'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final updatedMeal = widget.meal.copyWith(
      name: mealName,
      category: _category,
      ingredients: updatedIngredients,
      calories: _totalCalories,
      protein: _totalProtein,
      fats: _totalFats,
      carbs: _totalCarbs,
      fiber: _totalFiber,
      aiBreakdown: {
        'items': breakdownItems,
      },
    );

    context.read<DietBloc>().add(UpdateMealInLibrary(updatedMeal));
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Saved changes to "$mealName"!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final item in _ingredients) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 460 ? 440.0 : (screenWidth * 0.94);

    return Container(
      width: dialogWidth,
      constraints: BoxConstraints(
        maxWidth: 440,
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_outlined, color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Meal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Meal Name Input
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Meal Name *',
                        hintText: 'e.g. Grilled Chicken Salad',
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the meal name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Category Selector
                    const Text(
                      'Category',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _category == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                          checkmarkColor: AppTheme.accent,
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _category = cat;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Live Macro Summary Preview
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Calculated Macros (Live Preview)',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                '${_totalCalories.round()} kcal',
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'P: ${_totalProtein.toStringAsFixed(1)}g',
                                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                              ),
                              Text(
                                'F: ${_totalFats.toStringAsFixed(1)}g',
                                style: const TextStyle(color: Color(0xFFEAB308), fontSize: 12),
                              ),
                              Text(
                                'C: ${_totalCarbs.toStringAsFixed(1)}g',
                                style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12),
                              ),
                              if (_totalFiber > 0)
                                Text(
                                  'Fib: ${_totalFiber.toStringAsFixed(1)}g',
                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 12),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ingredients Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Ingredients & Portions',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addIngredient,
                          icon: const Icon(Icons.add, size: 16, color: AppTheme.accent),
                          label: const Text(
                            'Add Item',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Ingredients List
                    Column(
                      children: List.generate(_ingredients.length, (index) {
                        final item = _ingredients[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: item.nameController,
                                      onChanged: (_) => _onIngredientChanged(item),
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Item Name',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: item.weightController,
                                      onChanged: (_) => _onIngredientChanged(item),
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Portion / Weight',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    tooltip: 'Remove',
                                    onPressed: () => _removeIngredient(index),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.calories.round()} kcal • P: ${item.protein.toStringAsFixed(1)}g  F: ${item.fats.toStringAsFixed(1)}g  C: ${item.carbs.toStringAsFixed(1)}g',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Save Changes Button (Fixed at bottom)
          ElevatedButton.icon(
            onPressed: _saveChanges,
            icon: const Icon(Icons.check, size: 20),
            label: const Text(
              'Save Changes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
