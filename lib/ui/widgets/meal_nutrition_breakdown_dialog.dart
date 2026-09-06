import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../blocs/diet_bloc.dart';
import '../../core/theme.dart';
import '../../models/meal.dart';
import '../../services/food_analysis_service.dart';
import '../../services/meal_photo_service.dart';
import 'food_logging_dialog.dart';

class MealNutritionBreakdownDialog extends StatefulWidget {
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
  final String? photoUrl;

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
    this.photoUrl,
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
    String? photoUrl,
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
          photoUrl: photoUrl,
        ),
      ),
    );
  }

  @override
  State<MealNutritionBreakdownDialog> createState() => _MealNutritionBreakdownDialogState();
}

class _MealNutritionBreakdownDialogState extends State<MealNutritionBreakdownDialog> {
  double _currentMultiplier = 1.0;
  final List<double> _multipliers = [0.5, 1.0, 1.5, 2.0];

  late double _baseCalories;
  late double _baseProtein;
  late double _baseFats;
  late double _baseCarbs;
  late double _baseFiber;
  dynamic _currentAiBreakdown;
  String? _currentPhotoUrl;
  bool _isEstimating = false;
  bool _isUploadingPhoto = false;

  bool _isAddingIngredient = false;
  final TextEditingController _addNameController = TextEditingController();
  final TextEditingController _addWeightController = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    _baseCalories = widget.calories;
    _baseProtein = widget.protein;
    _baseFats = widget.fats;
    _baseCarbs = widget.carbs;
    _baseFiber = widget.fiber;
    _currentAiBreakdown = widget.aiBreakdown;
    _currentPhotoUrl = widget.photoUrl;
  }

  @override
  void dispose() {
    _addNameController.dispose();
    _addWeightController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final name = _addNameController.text.trim();
    if (name.isEmpty) return;

    final grams = double.tryParse(_addWeightController.text.trim()) ?? 100.0;

    // Estimate macros using LocalFoodParser
    final parsed = LocalFoodParser.parse(
      mealName: name,
      ingredients: ['$name ${grams.round()}g'],
    );

    final FoodAnalysisItem newItem;
    if (parsed.items.isNotEmpty) {
      newItem = parsed.items.first;
    } else {
      final mult = grams / 100.0;
      newItem = FoodAnalysisItem(
        name: name,
        weight: '${grams.round()}g',
        calories: (120.0 * mult).roundToDouble(),
        protein: double.parse((5.0 * mult).toStringAsFixed(1)),
        fats: double.parse((3.0 * mult).toStringAsFixed(1)),
        carbs: double.parse((15.0 * mult).toStringAsFixed(1)),
      );
    }

    final itemCal = newItem.calories ?? 0.0;
    final itemP = newItem.protein ?? 0.0;
    final itemF = newItem.fats ?? 0.0;
    final itemC = newItem.carbs ?? 0.0;
    final itemFiber = (parsed.fiber > 0) ? parsed.fiber : 0.0;

    List<Map<String, dynamic>> rawList = [];
    final currentRaw = _currentAiBreakdown ?? widget.aiBreakdown;
    if (currentRaw is List) {
      rawList = currentRaw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } else if (currentRaw is Map && currentRaw['items'] is List) {
      rawList = (currentRaw['items'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }

    rawList.add(newItem.toMap());

    setState(() {
      _baseCalories += itemCal;
      _baseProtein += itemP;
      _baseFats += itemF;
      _baseCarbs += itemC;
      _baseFiber += itemFiber;
      _currentAiBreakdown = rawList;
      _isAddingIngredient = false;
      _addNameController.clear();
      _addWeightController.text = '100';
    });

    final scaledCal = _baseCalories * _currentMultiplier;
    final scaledP = _baseProtein * _currentMultiplier;
    final scaledF = _baseFats * _currentMultiplier;
    final scaledC = _baseCarbs * _currentMultiplier;
    final scaledFiber = _baseFiber * _currentMultiplier;

    // Persist immediately to DietBloc & Supabase
    context.read<DietBloc>().add(
          LogActualMeal(
            date: widget.date,
            slotId: widget.slotId,
            actualMealName: widget.mealName,
            calories: scaledCal,
            protein: scaledP,
            fats: scaledF,
            carbs: scaledC,
            fiber: scaledFiber,
            userNote: _currentMultiplier != 1.0
                ? 'Serving size: ${_currentMultiplier == _currentMultiplier.roundToDouble() ? _currentMultiplier.toInt() : _currentMultiplier}x'
                : widget.userNote,
            aiBreakdown: rawList,
            completedAt: widget.completedAt ?? DateTime.now(),
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Added "${newItem.name}" (+${itemCal.round()} kcal)'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeIngredient(int index) {
    List<Map<String, dynamic>> rawList = [];
    final currentRaw = _currentAiBreakdown ?? widget.aiBreakdown;
    if (currentRaw is List) {
      rawList = currentRaw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } else if (currentRaw is Map && currentRaw['items'] is List) {
      rawList = (currentRaw['items'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }

    if (index >= 0 && index < rawList.length) {
      final removed = rawList.removeAt(index);
      final itemCal = (removed['calories'] as num?)?.toDouble() ?? 0.0;
      final itemP = (removed['protein_g'] ?? removed['protein'] as num?)?.toDouble() ?? 0.0;
      final itemF = (removed['fats_g'] ?? removed['fats'] as num?)?.toDouble() ?? 0.0;
      final itemC = (removed['carbs_g'] ?? removed['carbs'] as num?)?.toDouble() ?? 0.0;
      final itemFiber = (removed['fiber_g'] ?? removed['fiber'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        _baseCalories = (_baseCalories - itemCal).clamp(0.0, double.infinity);
        _baseProtein = (_baseProtein - itemP).clamp(0.0, double.infinity);
        _baseFats = (_baseFats - itemF).clamp(0.0, double.infinity);
        _baseCarbs = (_baseCarbs - itemC).clamp(0.0, double.infinity);
        _baseFiber = (_baseFiber - itemFiber).clamp(0.0, double.infinity);
        _currentAiBreakdown = rawList;
      });

      final scaledCal = _baseCalories * _currentMultiplier;
      final scaledP = _baseProtein * _currentMultiplier;
      final scaledF = _baseFats * _currentMultiplier;
      final scaledC = _baseCarbs * _currentMultiplier;
      final scaledFiber = _baseFiber * _currentMultiplier;

      context.read<DietBloc>().add(
            LogActualMeal(
              date: widget.date,
              slotId: widget.slotId,
              actualMealName: widget.mealName,
              calories: scaledCal,
              protein: scaledP,
              fats: scaledF,
              carbs: scaledC,
              fiber: scaledFiber,
              userNote: _currentMultiplier != 1.0
                  ? 'Serving size: ${_currentMultiplier == _currentMultiplier.roundToDouble() ? _currentMultiplier.toInt() : _currentMultiplier}x'
                  : widget.userNote,
              aiBreakdown: rawList,
              completedAt: widget.completedAt ?? DateTime.now(),
            ),
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed item from breakdown'),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _parseItems() {
    final breakdown = _currentAiBreakdown ?? widget.aiBreakdown;
    if (breakdown == null) return [];
    if (breakdown is List) {
      return breakdown
          .whereType<Map>()
          .map((item) {
            final itemCopy = Map<String, dynamic>.from(item);
            if (_currentMultiplier != 1.0) {
              if (itemCopy['calories'] is num) {
                itemCopy['calories'] = ((itemCopy['calories'] as num) * _currentMultiplier).round();
              }
              if (itemCopy['weight_g'] is num) {
                final scaledWeight = ((itemCopy['weight_g'] as num) * _currentMultiplier).round();
                itemCopy['weight_g'] = scaledWeight;
                itemCopy['weight'] = '${scaledWeight}g';
              } else if (itemCopy['weight'] is String && (itemCopy['weight'] as String).endsWith('g')) {
                final rawNum = double.tryParse((itemCopy['weight'] as String).replaceAll('g', ''));
                if (rawNum != null) {
                  itemCopy['weight'] = '${(rawNum * _currentMultiplier).round()}g';
                }
              }
            }
            return itemCopy;
          })
          .toList();
    }
    return [];
  }

  void _onMultiplierChanged(double newMultiplier) {
    if (_currentMultiplier == newMultiplier) return;

    setState(() {
      _currentMultiplier = newMultiplier;
    });

    final scaledCal = _baseCalories * newMultiplier;
    final scaledP = _baseProtein * newMultiplier;
    final scaledF = _baseFats * newMultiplier;
    final scaledC = _baseCarbs * newMultiplier;
    final scaledFiber = _baseFiber * newMultiplier;

    // Dispatches updated actual meal to DietBloc & Supabase
    context.read<DietBloc>().add(
          LogActualMeal(
            date: widget.date,
            slotId: widget.slotId,
            actualMealName: widget.mealName,
            calories: scaledCal,
            protein: scaledP,
            fats: scaledF,
            carbs: scaledC,
            fiber: scaledFiber,
            userNote: newMultiplier != 1.0 ? 'Serving size: ${newMultiplier == newMultiplier.roundToDouble() ? newMultiplier.toInt() : newMultiplier}x' : widget.userNote,
            aiBreakdown: _currentAiBreakdown ?? widget.aiBreakdown,
            completedAt: widget.completedAt ?? DateTime.now(),
          ),
        );
  }

  Future<void> _estimateMacros() async {
    final items = _parseItems();
    final ingredients = items
        .map((i) => i['name']?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() {
      _isEstimating = true;
    });

    try {
      final result = await FoodAnalysisService().estimateNutritionalValues(
        mealName: widget.mealName,
        ingredients: ingredients,
        userNote: widget.userNote,
      );

      final newBreakdown = result.items.isNotEmpty
          ? result.items.map((i) => i.toMap()).toList()
          : _currentAiBreakdown;

      setState(() {
        _baseCalories = result.calories;
        _baseProtein = result.protein;
        _baseFats = result.fats;
        _baseCarbs = result.carbs;
        _baseFiber = result.fiber;
        _currentAiBreakdown = newBreakdown;
      });

      final scaledCal = _baseCalories * _currentMultiplier;
      final scaledP = _baseProtein * _currentMultiplier;
      final scaledF = _baseFats * _currentMultiplier;
      final scaledC = _baseCarbs * _currentMultiplier;
      final scaledFiber = _baseFiber * _currentMultiplier;

      if (mounted) {
        context.read<DietBloc>().add(
              LogActualMeal(
                date: widget.date,
                slotId: widget.slotId,
                actualMealName: widget.mealName,
                calories: scaledCal,
                protein: scaledP,
                fats: scaledF,
                carbs: scaledC,
                fiber: scaledFiber,
                userNote: _currentMultiplier != 1.0
                    ? 'Serving size: ${_currentMultiplier == _currentMultiplier.roundToDouble() ? _currentMultiplier.toInt() : _currentMultiplier}x'
                    : widget.userNote,
                aiBreakdown: newBreakdown,
                completedAt: widget.completedAt ?? DateTime.now(),
              ),
            );

        // Also check if meal exists in library and update it permanently
        final dietState = context.read<DietBloc>().state;
        final libraryMealIdx = dietState.mealsLibrary.indexWhere(
          (m) => m.name.toLowerCase().trim() == widget.mealName.toLowerCase().trim(),
        );
        if (libraryMealIdx >= 0) {
          final existingMeal = dietState.mealsLibrary[libraryMealIdx];
          final updatedMeal = existingMeal.copyWith(
            calories: result.calories,
            protein: result.protein,
            fats: result.fats,
            carbs: result.carbs,
            fiber: result.fiber,
            aiBreakdown: newBreakdown,
          );
          context.read<DietBloc>().add(UpdateMealInLibrary(updatedMeal));
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Estimated nutrition: ${result.calories.round()} kcal for "${widget.mealName}"'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estimation failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEstimating = false;
        });
      }
    }
  }

  void _saveToLibrary(BuildContext context) {
    final items = _parseItems();
    final ingredients = items
        .map((i) => i['name']?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    String category = 'Breakfast';
    final lowerSlot = widget.slotName.toLowerCase();
    if (lowerSlot.contains('lunch')) {
      category = 'Lunch';
    } else if (lowerSlot.contains('dinner')) {
      category = 'Dinner';
    } else if (lowerSlot.contains('snack')) {
      category = 'Snack';
    }

    final newMeal = Meal(
      id: const Uuid().v4(),
      name: widget.mealName,
      category: category,
      ingredients: ingredients.isNotEmpty ? ingredients : [widget.mealName],
      calories: _baseCalories * _currentMultiplier,
      protein: _baseProtein * _currentMultiplier,
      fats: _baseFats * _currentMultiplier,
      carbs: _baseCarbs * _currentMultiplier,
      fiber: _baseFiber * _currentMultiplier,
      aiBreakdown: items.isNotEmpty ? items : widget.aiBreakdown,
      defaultServings: _currentMultiplier,
    );

    context.read<DietBloc>().add(AddMealToLibrary(newMeal));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ "${widget.mealName}" saved to Meals Library!'),
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
                'Are you sure you want to clear "${widget.mealName}" from ${widget.slotName}? The daily nutrition totals will be recalculated.',
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
                        context.read<DietBloc>().add(ClearActualMeal(date: widget.date, slotId: widget.slotId));
                        Navigator.pop(context); // pop breakdown
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Cleared meal from ${widget.slotName}'),
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

  Future<void> _attachOrChangePhoto(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final dietBloc = context.read<DietBloc>();
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.accent),
                title: const Text('Take Photo', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.accent),
                title: const Text('Choose from Gallery', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? photo = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (photo == null || !mounted) return;

      setState(() {
        _isUploadingPhoto = true;
      });

      final uploadedUrl = await MealPhotoService.uploadMealPhoto(
        image: photo,
        slotId: widget.slotId,
      );

      if (!mounted) return;

      setState(() {
        _isUploadingPhoto = false;
        if (uploadedUrl != null) {
          _currentPhotoUrl = uploadedUrl;
        }
      });

      if (uploadedUrl != null) {
        dietBloc.add(
          UpdateSlotPhoto(
            date: widget.date,
            slotId: widget.slotId,
            photoUrl: uploadedUrl,
          ),
        );

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('✓ Meal photo updated!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to upload photo. Please check your connection.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = false;
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error updating photo: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _openEditDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _EditMealNutritionDialog(
        date: widget.date,
        slotId: widget.slotId,
        slotName: widget.slotName,
        initialName: widget.mealName,
        initialCalories: _baseCalories * _currentMultiplier,
        initialProtein: _baseProtein * _currentMultiplier,
        initialFats: _baseFats * _currentMultiplier,
        initialCarbs: _baseCarbs * _currentMultiplier,
        initialFiber: _baseFiber * _currentMultiplier,
        initialUserNote: widget.userNote,
        aiBreakdown: widget.aiBreakdown,
        completedAt: widget.completedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 460 ? 420.0 : (screenWidth * 0.92);
    final items = _parseItems();

    final curCal = _baseCalories * _currentMultiplier;
    final curP = _baseProtein * _currentMultiplier;
    final curF = _baseFats * _currentMultiplier;
    final curC = _baseCarbs * _currentMultiplier;
    final curFiber = _baseFiber * _currentMultiplier;

    String timeStr = '';
    if (widget.completedAt != null) {
      timeStr = DateFormat('hh:mm a').format(widget.completedAt!);
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
                                  text: widget.slotName,
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
                  // Meal Name Banner & Servings Multiplier Selector
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
                            const Text(
                              'LOGGED DISH',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            // Servings Multiplier chips
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: _multipliers.map((m) {
                                final isSelected = (_currentMultiplier == m);
                                final label = '${m == m.roundToDouble() ? m.toInt() : m}x';

                                return Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: InkWell(
                                    onTap: () => _onMultiplierChanged(m),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppTheme.accent : const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected ? AppTheme.accent : const Color(0xFF334155),
                                        ),
                                      ),
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color: isSelected ? AppTheme.background : AppTheme.textPrimary,
                                          fontSize: 10,
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
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  color: const Color(0xFF1E293B),
                                  child: MealPhotoService.buildMealImage(
                                    photoUrl: _currentPhotoUrl!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorWidget: Container(
                                      width: 48,
                                      height: 48,
                                      color: const Color(0xFF1E293B),
                                      child: const Icon(Icons.broken_image_outlined, size: 20, color: AppTheme.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.mealName,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: _isUploadingPhoto ? null : () => _attachOrChangePhoto(context),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _currentPhotoUrl != null ? Icons.photo_camera_outlined : Icons.add_a_photo_outlined,
                                          size: 13,
                                          color: AppTheme.accent,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _isUploadingPhoto
                                              ? 'Uploading...'
                                              : (_currentPhotoUrl != null ? 'Change Photo' : 'Attach Photo'),
                                          style: const TextStyle(
                                            color: AppTheme.accent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                        Expanded(child: _buildMacroBadge('${curCal.toStringAsFixed(0)} kcal', 'Calories', const Color(0xFFF59E0B))),
                        Expanded(child: _buildMacroBadge('${curP.toStringAsFixed(1)}g', 'Protein', const Color(0xFFEF4444))),
                        Expanded(child: _buildMacroBadge('${curF.toStringAsFixed(1)}g', 'Fats', const Color(0xFFEAB308))),
                        Expanded(child: _buildMacroBadge('${curC.toStringAsFixed(1)}g', 'Carbs', const Color(0xFF3B82F6))),
                        Expanded(child: _buildMacroBadge('${curFiber.toStringAsFixed(1)}g', 'Fiber', const Color(0xFF10B981))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // AI Macro Estimation Banner / Action (if macros are 0/empty)
                  if (curCal <= 0 && curP <= 0 && curF <= 0 && curC <= 0) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: AppTheme.accent, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Missing Nutrition Info',
                                style: TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'This meal has 0 recorded macros. PlateMate AI can estimate calories and macros based on ingredients and meal name.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isEstimating ? null : _estimateMacros,
                              icon: _isEstimating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome, size: 16),
                              label: Text(
                                _isEstimating ? 'Estimating Macros...' : 'Estimate Macros with AI',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Ingredients / Food items breakdown & Add Ingredient section
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
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ...items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final name = item['name']?.toString() ?? 'Item';
                            final weight = item['weight']?.toString() ??
                                (item['weight_g'] != null ? '${item['weight_g']}g' : null);
                            final itemCal = (item['calories'] as num?)?.toDouble();

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
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
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                        const SizedBox(width: 6),
                                        Text(
                                          '${itemCal.toStringAsFixed(0)} kcal',
                                          style: const TextStyle(
                                            color: Color(0xFFF59E0B),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () => _removeIngredient(idx),
                                        child: const Padding(
                                          padding: EdgeInsets.all(2),
                                          child: Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 10),

                        // Inline Add Ingredient Form or Button
                        if (_isAddingIngredient)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Row(
                                        children: [
                                          Icon(Icons.add_circle_outline, size: 16, color: AppTheme.accent),
                                          SizedBox(width: 6),
                                          Text(
                                            'Add Missing Ingredient',
                                            style: TextStyle(
                                              color: AppTheme.accent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isAddingIngredient = false;
                                        });
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _addNameController,
                                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          labelText: 'Ingredient Name',
                                          hintText: 'e.g., Canned Tuna, Boiled Egg',
                                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                          filled: true,
                                          fillColor: const Color(0xFF0F172A),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF334155)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF334155)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: AppTheme.accent),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: _addWeightController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          labelText: 'Weight',
                                          suffixText: 'g',
                                          filled: true,
                                          fillColor: const Color(0xFF0F172A),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF334155)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF334155)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: AppTheme.accent),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _isAddingIngredient = false;
                                        });
                                      },
                                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: _addIngredient,
                                      icon: const Icon(Icons.add, size: 14),
                                      label: const Text('Add Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accent,
                                        foregroundColor: AppTheme.background,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isAddingIngredient = true;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: 16, color: AppTheme.accent),
                                  SizedBox(width: 6),
                                  Text(
                                    '+ Add Ingredient',
                                    style: TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // User Note Card
                  if (widget.userNote != null && widget.userNote!.isNotEmpty) ...[
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
                                  widget.userNote!,
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
                        date: widget.date,
                        slotId: widget.slotId,
                        slotName: widget.slotName,
                        initialMealName: widget.mealName,
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

  final List<double> _quickMultipliers = [0.5, 1.0, 1.5, 2.0];

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

  void _applyMultiplier(double multiplier) {
    setState(() {
      _caloriesController.text = (widget.initialCalories * multiplier).toStringAsFixed(0);
      _proteinController.text = (widget.initialProtein * multiplier).toStringAsFixed(1);
      _fatsController.text = (widget.initialFats * multiplier).toStringAsFixed(1);
      _carbsController.text = (widget.initialCarbs * multiplier).toStringAsFixed(1);
      _fiberController.text = (widget.initialFiber * multiplier).toStringAsFixed(1);
    });
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

            // Quick Scale Portion Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quick Scale Portion:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: _quickMultipliers.map((m) {
                    final label = '${m == m.roundToDouble() ? m.toInt() : m}x';
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: InkWell(
                        onTap: () => _applyMultiplier(m),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 14),

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

