import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../blocs/diet_bloc.dart';
import '../../core/theme.dart';
import '../../models/meal.dart';
import 'food_logging_dialog.dart';

class MealNutritionBreakdownDialog extends StatelessWidget {
  final DateTime date;
  final String slotId;
  final String slotName;
  final String mealName;
  final double calories;
  final double protein;
  final double fats;
  final double carbs;
  final double fiber;
  final String? userNote;
  final dynamic aiBreakdown;
  final DateTime? completedAt;

  const MealNutritionBreakdownDialog({
    super.key,
    required this.date,
    required this.slotId,
    required this.slotName,
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.fats,
    required this.carbs,
    required this.fiber,
    this.userNote,
    this.aiBreakdown,
    this.completedAt,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    required String slotId,
    required String slotName,
    required String mealName,
    required double calories,
    required double protein,
    required double fats,
    required double carbs,
    required double fiber,
    String? userNote,
    dynamic aiBreakdown,
    DateTime? completedAt,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: MealNutritionBreakdownDialog(
          date: date,
          slotId: slotId,
          slotName: slotName,
          mealName: mealName,
          calories: calories,
          protein: protein,
          fats: fats,
          carbs: carbs,
          fiber: fiber,
          userNote: userNote,
          aiBreakdown: aiBreakdown,
          completedAt: completedAt,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _parseItems() {
    if (aiBreakdown == null) return [];
    if (aiBreakdown is List) {
      return (aiBreakdown as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    return [];
  }

  void _saveToLibrary(BuildContext context) {
    final items = _parseItems();
    final ingredients = items
        .map((i) => i['name']?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    String category = 'Breakfast';
    final lowerSlot = slotName.toLowerCase();
    if (lowerSlot.contains('lunch')) {
      category = 'Lunch';
    } else if (lowerSlot.contains('dinner')) {
      category = 'Dinner';
    } else if (lowerSlot.contains('snack')) {
      category = 'Snack';
    }

    final newMeal = Meal(
      id: const Uuid().v4(),
      name: mealName,
      category: category,
      ingredients: ingredients.isNotEmpty ? ingredients : [mealName],
    );

    context.read<DietBloc>().add(AddMealToLibrary(newMeal));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ "$mealName" saved to Meals Library!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Clear Logged Meal',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Are you sure you want to clear "$mealName" from $slotName? The daily nutrition totals will be recalculated.',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx); // pop confirm
                        context.read<DietBloc>().add(ClearActualMeal(date: date, slotId: slotId));
                        Navigator.pop(context); // pop breakdown
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Cleared meal from $slotName'),
                            backgroundColor: const Color(0xFF0F172A),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _EditMealNutritionDialog(
        date: date,
        slotId: slotId,
        slotName: slotName,
        initialName: mealName,
        initialCalories: calories,
        initialProtein: protein,
        initialFats: fats,
        initialCarbs: carbs,
        initialFiber: fiber,
        initialUserNote: userNote,
        aiBreakdown: aiBreakdown,
        completedAt: completedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 460 ? 420.0 : (screenWidth * 0.92);
    final items = _parseItems();

    String timeStr = '';
    if (completedAt != null) {
      timeStr = DateFormat('hh:mm a').format(completedAt!);
    }

    return Container(
      width: dialogWidth,
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(20),
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.analytics_outlined, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Meal Nutrition Breakdown',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: slotName,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (timeStr.isNotEmpty) ...[
                                  const TextSpan(
                                    text: ' • ',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                  TextSpan(
                                    text: 'Eaten at $timeStr',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.bookmark_add_outlined, color: AppTheme.accent, size: 20),
                    tooltip: 'Save to Meals Library',
                    onPressed: () => _saveToLibrary(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scrollable details
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Meal Name Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LOGGED DISH',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mealName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Macro Summary Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildMacroBadge('${calories.toStringAsFixed(0)} kcal', 'Calories', const Color(0xFFF59E0B))),
                        Expanded(child: _buildMacroBadge('${protein.toStringAsFixed(1)}g', 'Protein', const Color(0xFFEF4444))),
                        Expanded(child: _buildMacroBadge('${fats.toStringAsFixed(1)}g', 'Fats', const Color(0xFFEAB308))),
                        Expanded(child: _buildMacroBadge('${carbs.toStringAsFixed(1)}g', 'Carbs', const Color(0xFF3B82F6))),
                        Expanded(child: _buildMacroBadge('${fiber.toStringAsFixed(1)}g', 'Fiber', const Color(0xFF10B981))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Ingredients / Food items breakdown
                  if (items.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Recognized Ingredients & Portions',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '${items.length} items',
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...items.map((item) {
                            final name = item['name']?.toString() ?? 'Item';
                            final weight = item['weight']?.toString() ??
                                (item['weight_g'] != null ? '${item['weight_g']}g' : null);
                            final itemCal = (item['calories'] as num?)?.toDouble();

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.circle, size: 6, color: AppTheme.accent),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (weight != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF334155)),
                                      ),
                                      child: Text(
                                        weight,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  if (itemCal != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '${itemCal.toStringAsFixed(0)} kcal',
                                      style: const TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // User Note Card
                  if (userNote != null && userNote!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.note_alt_outlined, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'User Note',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userNote!,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showDeleteConfirm(context),
                icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                label: const Text('Clear Slot', style: TextStyle(color: AppTheme.error, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openEditDialog(context),
                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textPrimary),
                    label: const Text('Edit', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      FoodLoggingDialog.show(
                        context,
                        date: date,
                        slotId: slotId,
                        slotName: slotName,
                        initialMealName: mealName,
                      );
                    },
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text(
                      'Re-analyze',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.background,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBadge(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _EditMealNutritionDialog extends StatefulWidget {
  final DateTime date;
  final String slotId;
  final String slotName;
  final String initialName;
  final double initialCalories;
  final double initialProtein;
  final double initialFats;
  final double initialCarbs;
  final double initialFiber;
  final String? initialUserNote;
  final dynamic aiBreakdown;
  final DateTime? completedAt;

  const _EditMealNutritionDialog({
    required this.date,
    required this.slotId,
    required this.slotName,
    required this.initialName,
    required this.initialCalories,
    required this.initialProtein,
    required this.initialFats,
    required this.initialCarbs,
    required this.initialFiber,
    this.initialUserNote,
    this.aiBreakdown,
    this.completedAt,
  });

  @override
  State<_EditMealNutritionDialog> createState() => _EditMealNutritionDialogState();
}

class _EditMealNutritionDialogState extends State<_EditMealNutritionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _fatsController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fiberController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _caloriesController = TextEditingController(text: widget.initialCalories.toStringAsFixed(0));
    _proteinController = TextEditingController(text: widget.initialProtein.toStringAsFixed(1));
    _fatsController = TextEditingController(text: widget.initialFats.toStringAsFixed(1));
    _carbsController = TextEditingController(text: widget.initialCarbs.toStringAsFixed(1));
    _fiberController = TextEditingController(text: widget.initialFiber.toStringAsFixed(1));
    _noteController = TextEditingController(text: widget.initialUserNote ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatsController.dispose();
    _carbsController.dispose();
    _fiberController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    if (!_formKey.currentState!.validate()) return;

    final updatedName = _nameController.text.trim();
    final updatedCalories = double.tryParse(_caloriesController.text.trim()) ?? 0.0;
    final updatedProtein = double.tryParse(_proteinController.text.trim()) ?? 0.0;
    final updatedFats = double.tryParse(_fatsController.text.trim()) ?? 0.0;
    final updatedCarbs = double.tryParse(_carbsController.text.trim()) ?? 0.0;
    final updatedFiber = double.tryParse(_fiberController.text.trim()) ?? 0.0;
    final updatedNote = _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null;

    context.read<DietBloc>().add(
          LogActualMeal(
            date: widget.date,
            slotId: widget.slotId,
            actualMealName: updatedName,
            calories: updatedCalories,
            protein: updatedProtein,
            fats: updatedFats,
            carbs: updatedCarbs,
            fiber: updatedFiber,
            userNote: updatedNote,
            aiBreakdown: widget.aiBreakdown,
            completedAt: widget.completedAt ?? DateTime.now(),
          ),
        );

    Navigator.pop(context); // pop edit dialog
    Navigator.pop(context); // pop breakdown dialog

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ "$updatedName" updated successfully!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 460 ? 420.0 : (screenWidth * 0.92);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
                      child: const Icon(Icons.edit_note, color: AppTheme.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Edit Meal Nutrition',
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
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scrollable Form
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Dish Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Dish Name',
                          hintText: 'e.g., Grilled Chicken & Rice',
                        ),
                        style: const TextStyle(color: AppTheme.textPrimary),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter dish name' : null,
                      ),
                      const SizedBox(height: 14),

                      // Calories & Protein Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _caloriesController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Calories (kcal)',
                                suffixText: 'kcal',
                              ),
                              style: const TextStyle(color: AppTheme.textPrimary),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _proteinController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Protein (g)',
                                suffixText: 'g',
                              ),
                              style: const TextStyle(color: AppTheme.textPrimary),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Fats & Carbs Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _fatsController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Fats (g)',
                                suffixText: 'g',
                              ),
                              style: const TextStyle(color: AppTheme.textPrimary),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _carbsController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Carbs (g)',
                                suffixText: 'g',
                              ),
                              style: const TextStyle(color: AppTheme.textPrimary),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Fiber
                      TextFormField(
                        controller: _fiberController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Fiber (g)',
                          suffixText: 'g',
                        ),
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 12),

                      // User Note
                      TextFormField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'e.g. cooked with olive oil, no sauce',
                        ),
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.background,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

