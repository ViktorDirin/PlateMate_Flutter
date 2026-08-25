import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/diet_bloc.dart';
import '../../core/theme.dart';
import '../../models/diet_plan.dart';
import '../widgets/time_input_formatter.dart';
import 'meal_library_screen.dart';

class DietDetailScreen extends StatefulWidget {
  final String dietId;
  const DietDetailScreen({super.key, required this.dietId});

  @override
  State<DietDetailScreen> createState() => _DietDetailScreenState();
}

class _DietDetailScreenState extends State<DietDetailScreen> {
  late DateTime _selectedDate;
  Timer? _fastingTimer;
  String _fastingDurationStr = '00:00';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _startFastingTimer();
  }

  @override
  void dispose() {
    _fastingTimer?.cancel();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  void _startFastingTimer() {
    _calculateFastingTime();
    _fastingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _calculateFastingTime();
    });
  }

  void _calculateFastingTime() {
    final bloc = context.read<DietBloc>();
    final dietState = bloc.state;
    final diet = dietState.diets.firstWhere((d) => d.id == widget.dietId, orElse: () => DietPlan(name: '', meals: []));
    
    if (diet.name.isEmpty || diet.meals.isEmpty) {
      if (mounted) {
        setState(() {
          _fastingDurationStr = '00:00';
        });
      }
      return;
    }

    final now = DateTime.now();
    final todayStr = _formatDate(now);
    
    // Find past meals for today
    DateTime? lastMealDateTime;

    for (var meal in diet.meals) {
      if (meal.date == todayStr) {
        final mealTimeParts = meal.time.split(':');
        if (mealTimeParts.length == 2) {
          final hour = int.tryParse(mealTimeParts[0]) ?? 0;
          final minute = int.tryParse(mealTimeParts[1]) ?? 0;
          final mealDateTime = DateTime(now.year, now.month, now.day, hour, minute);
          
          if (mealDateTime.isBefore(now)) {
            if (lastMealDateTime == null || mealDateTime.isAfter(lastMealDateTime)) {
              lastMealDateTime = mealDateTime;
            }
          }
        }
      }
    }

    // If no meals in the past today, check yesterday
    if (lastMealDateTime == null) {
      final yesterdayStr = _formatDate(now.subtract(const Duration(days: 1)));
      for (var meal in diet.meals) {
        if (meal.date == yesterdayStr) {
          final mealTimeParts = meal.time.split(':');
          if (mealTimeParts.length == 2) {
            final hour = int.tryParse(mealTimeParts[0]) ?? 0;
            final minute = int.tryParse(mealTimeParts[1]) ?? 0;
            final mealDateTime = DateTime(now.year, now.month, now.day - 1, hour, minute);
            
            if (lastMealDateTime == null || mealDateTime.isAfter(lastMealDateTime)) {
              lastMealDateTime = mealDateTime;
            }
          }
        }
      }
    }

    if (lastMealDateTime != null) {
      final difference = now.difference(lastMealDateTime);
      final hours = difference.inHours.toString().padLeft(2, '0');
      final minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
      if (mounted) {
        setState(() {
          _fastingDurationStr = '$hours:$minutes';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _fastingDurationStr = '--:--';
        });
      }
    }
  }

  void _editMealTime(Meal meal, DietPlan diet) {
    final controller = TextEditingController(text: meal.time);
    showDialog(
      context: context,
      builder: (context) {
        return Align(
          alignment: const Alignment(0, -0.4), // Position in the upper third
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Изменить время',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [TimeInputFormatter()],
                    decoration: const InputDecoration(
                      hintText: 'ЧЧ:ММ',
                      labelText: 'Время приема пищи',
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final rawTime = controller.text.trim();
                          final normalizedTime = TimeInputFormatter.normalizeTime(rawTime);
                          final updatedMeal = meal.copyWith(time: normalizedTime);
                          
                          final updatedMeals = diet.meals.map((m) => m.id == meal.id ? updatedMeal : m).toList();
                          context.read<DietBloc>().add(UpdateDiet(diet.copyWith(meals: updatedMeals)));
                          
                          Navigator.pop(context);
                          _calculateFastingTime();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                        child: const Text('Сохранить', style: TextStyle(color: AppTheme.background, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _deleteMeal(Meal meal, DietPlan diet) {
    final updatedMeals = diet.meals.where((m) => m.id != meal.id).toList();
    context.read<DietBloc>().add(UpdateDiet(diet.copyWith(meals: updatedMeals)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateFastingTime());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DietBloc, DietState>(
      builder: (context, state) {
        final diet = state.diets.firstWhere(
          (d) => d.id == widget.dietId,
          orElse: () => DietPlan(name: 'Не найдено', meals: []),
        );

        if (diet.name == 'Не найдено') {
          return const Scaffold(
            body: Center(child: Text('План питания удален или не найден.')),
          );
        }

        final selectedDateStr = _formatDate(_selectedDate);
        final todayStr = _formatDate(DateTime.now());
        final tomorrowStr = _formatDate(DateTime.now().add(const Duration(days: 1)));

        // Filter meals by category and date
        List<Meal> mealsForCategory(String category) {
          final filtered = diet.meals.where((m) => m.category == category && m.date == selectedDateStr).toList();
          filtered.sort((a, b) => a.time.compareTo(b.time));
          return filtered;
        }

        final breakfastMeals = mealsForCategory('Breakfast');
        final lunchMeals = mealsForCategory('Lunch');
        final dinnerMeals = mealsForCategory('Dinner');

        // Cloud sync indicator
        Color syncColor = AppTheme.textSecondary;
        IconData syncIcon = Icons.cloud_queue;
        if (state.isSyncing) {
          syncColor = AppTheme.warning;
          syncIcon = Icons.cloud_sync;
        } else if (state.syncFailed) {
          syncColor = AppTheme.error;
          syncIcon = Icons.cloud_off;
        } else {
          syncColor = AppTheme.success;
          syncIcon = Icons.cloud_done;
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(diet.name),
            actions: [
              IconButton(
                icon: Icon(syncIcon, color: syncColor),
                onPressed: () {
                  context.read<DietBloc>().add(SyncWithCloud());
                },
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Day Navigation Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _buildDayButton('Сегодня', selectedDateStr == todayStr, () {
                            setState(() {
                              _selectedDate = DateTime.now();
                            });
                          }),
                          const SizedBox(width: 8),
                          _buildDayButton('Завтра', selectedDateStr == tomorrowStr, () {
                            setState(() {
                              _selectedDate = DateTime.now().add(const Duration(days: 1));
                            });
                          }),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, color: AppTheme.accent),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppTheme.accent,
                                  onPrimary: AppTheme.background,
                                  surface: AppTheme.cardBg,
                                  onSurface: AppTheme.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

              // 2. Fasting Timer Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'ВРЕМЯ БЕЗ ЕДЫ СЕГОДНЯ',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _fastingDurationStr,
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Meals List (Breakfast, Lunch, Dinner)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _buildMealSection('Завтрак', 'Breakfast', breakfastMeals, diet),
                    const SizedBox(height: 20),
                    _buildMealSection('Ланч', 'Lunch', lunchMeals, diet),
                    const SizedBox(height: 20),
                    _buildMealSection('Обед / Ужин', 'Dinner', dinnerMeals, diet),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayButton(String label, bool isSelected, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppTheme.accent : AppTheme.cardBg,
        foregroundColor: isSelected ? AppTheme.background : AppTheme.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppTheme.accent : const Color(0xFF334155),
            width: 1,
          ),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMealSection(String title, String category, List<Meal> meals, DietPlan diet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.accent),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MealLibraryScreen(
                      onMealSelected: (selectedMeal) {
                        // Create a copy scheduled for this date and category
                        final newMeal = selectedMeal.copyWith(
                          date: _formatDate(_selectedDate),
                          category: category,
                          sortOrder: meals.length,
                        );
                        final updatedMeals = List<Meal>.from(diet.meals)..add(newMeal);
                        context.read<DietBloc>().add(UpdateDiet(diet.copyWith(meals: updatedMeals)));
                        _calculateFastingTime();
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (meals.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5), width: 1),
            ),
            child: const Text(
              'Нет добавленных блюд',
              style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...meals.map((meal) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  meal.name,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: meal.ingredients.isNotEmpty
                    ? Text(
                        meal.ingredients.map((i) => '${i.name} (${i.quantity} ${i.unit})').join(', '),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : const Text(
                        'Нет ингредиентов',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      meal.time,
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: AppTheme.textSecondary),
                      onPressed: () => _editMealTime(meal, diet),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: AppTheme.error),
                      onPressed: () => _deleteMeal(meal, diet),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
