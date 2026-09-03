import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'blocs/diet_bloc.dart';
import 'core/theme.dart';
import 'models/meal.dart';
import 'models/day_plan.dart';
import 'models/meal_slot_config.dart';
import 'ui/screens/meals_library_screen.dart';
import 'ui/screens/grocery_list_screen.dart';
import 'ui/screens/slots_management_screen.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/widgets/food_logging_dialog.dart';
import 'ui/widgets/meal_nutrition_breakdown_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize HydratedBloc Storage
  try {
    final storage = await HydratedStorage.build(
      storageDirectory: kIsWeb
          ? HydratedStorageDirectory.web
          : HydratedStorageDirectory((await getApplicationDocumentsDirectory()).path),
    );
    HydratedBloc.storage = storage;
  } catch (e) {
    debugPrint('HydratedBloc storage initialization failed: $e');
  }

  // 2. Initialize Supabase (Handles offline/missing configs gracefully)
  await Supabase.initialize(
    url: 'https://kblikxcemsiieqogizua.supabase.co',
    publishableKey: 'sb_publishable_gTsEUsUQx9jzgiWtLQLqMg_-LAte3uK',
  );

  runApp(const PlateMateApp());
}

class PlateMateApp extends StatelessWidget {
  const PlateMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DietBloc(),
      child: MaterialApp(
        title: 'PlateMate',
        theme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark, // Forced Dark Mode
        debugShowCheckedModeBanner: false,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStateStream;

  @override
  void initState() {
    super.initState();
    _authStateStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStateStream,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          context.read<DietBloc>().add(SyncDataFromSupabase());
          return const HomeScreen();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}

// --- Custom Dashed Border Painter ---
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedBorderPainter({
    this.color = Colors.grey,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.dashLength = 6.0,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth),
        Radius.circular(borderRadius),
      ));

    for (PathMetric measurePath in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < measurePath.length) {
        final length = dashLength;
        canvas.drawPath(
          measurePath.extractPath(distance, distance + length),
          paint,
        );
        distance += length + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashedContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  const DashedContainer({
    super.key,
    required this.child,
    this.color = Colors.grey,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.dashLength = 6.0,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DashedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        gap: gap,
        dashLength: dashLength,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

// --- HomeScreen View with BottomNavigationBar ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<DateTime> _generateCurrentWeek() {
    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    final startOfWeek = now.subtract(Duration(days: currentWeekday - 1));
    return List.generate(7, (index) => DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day + index,
    ));
  }

  void _pickMealForSlot(BuildContext context, DateTime date, String slotId, String slotName) {
    // Attempt to map custom slot name to standard category filters
    final cleanName = slotName.toLowerCase();
    String? categoryFilter;
    if (cleanName.contains('breakfast')) {
      categoryFilter = 'Breakfast';
    } else if (cleanName.contains('lunch')) {
      categoryFilter = 'Lunch';
    } else if (cleanName.contains('dinner')) {
      categoryFilter = 'Dinner';
    } else if (cleanName.contains('snack')) {
      categoryFilter = 'Snack';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealsLibraryScreen(
          filterCategory: categoryFilter,
          onMealPicked: (mealId) {
            context.read<DietBloc>().add(
                  ScheduleMealToSlot(date: date, slotId: slotId, mealId: mealId),
                );
          },
        ),
      ),
    );
  }

  void _pickSnackForSlot(BuildContext context, DateTime date, String slotId, String slotName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealsLibraryScreen(
          filterCategory: 'Snack',
          onMealPicked: (mealId) {
            context.read<DietBloc>().add(
                  AddSnackToSlot(date: date, slotId: slotId, mealId: mealId),
                );
          },
        ),
      ),
    );
  }

  Widget _buildEatenTimeBadge(String slotId, DateTime completedAt) {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(completedAt),
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
        if (time != null && mounted) {
          final updated = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            time.hour,
            time.minute,
          );
          context.read<DietBloc>().add(
            UpdateMealCompletionTime(
              date: _selectedDate,
              slotId: slotId,
              completedAt: updated,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 12, color: AppTheme.accent),
            const SizedBox(width: 4),
            Text(
              'Eaten: ${_formatTimeOfDay(completedAt)}',
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeOfDay(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
    final formattedMinute = minute.toString().padLeft(2, '0');
    return '$formattedHour:$formattedMinute $ampm';
  }

  Widget _buildLastMealBanner(DietState state) {
    final now = DateTime.now();
    DateTime? latestEatenToday;

    for (final plan in state.dayPlans) {
      if (plan.date.year == now.year && plan.date.month == now.month && plan.date.day == now.day) {
        plan.slotCompletedAt.forEach((slotId, completedAt) {
          final isCompleted = plan.slotCompleted[slotId] ?? false;
          if (isCompleted && completedAt != null) {
            if (latestEatenToday == null || completedAt.isAfter(latestEatenToday!)) {
              latestEatenToday = completedAt;
            }
          }
        });
      }
    }

    String bannerText;
    if (latestEatenToday != null) {
      final diff = now.difference(latestEatenToday!);
      if (diff.isNegative) {
        bannerText = '⏱️ Last meal: 0h 0m ago';
      } else {
        final hours = diff.inHours;
        final minutes = diff.inMinutes % 60;
        bannerText = '⏱️ Last meal: ${hours}h ${minutes}m ago';
      }
    } else {
      bannerText = '⏱️ No meals eaten today yet';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              bannerText,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDaySelector() {
    final weekDays = _generateCurrentWeek();
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: weekDays.length,
        itemBuilder: (context, index) {
          final date = weekDays[index];
          final isSelected = _isSameDate(date, _selectedDate);
          final weekdayStr = DateFormat('E').format(date); // Mon, Tue...
          final dayStr = DateFormat('d').format(date); // 26, 27...

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
            },
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.accent : const Color(0xFF334155),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayStr,
                    style: TextStyle(
                      color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayStr,
                    style: TextStyle(
                      color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildEmptySlot(String slotId, String slotName, DayPlan dayPlan) {
    final isActual = dayPlan.slotIsActual[slotId] ?? false;
    if (isActual) {
      return _buildActualSlot(slotId, slotName, dayPlan);
    }

    return DashedContainer(
      color: const Color(0xFF475569), // Slate grey dashed outline
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              slotName,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => FoodLoggingDialog.show(
                    context,
                    date: _selectedDate,
                    slotId: slotId,
                    slotName: slotName,
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 14),
                  label: const Text('Log (AI)', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _pickMealForSlot(context, _selectedDate, slotId, slotName),
                  icon: const Icon(Icons.add, size: 14),
                  label: Text('Add $slotName', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardBg,
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSlot(String slotId, String slotName, Meal meal, DayPlan dayPlan) {
    final isActual = dayPlan.slotIsActual[slotId] ?? false;
    if (isActual) {
      return _buildActualSlot(slotId, slotName, dayPlan, plannedMeal: meal);
    }

    final isCompleted = dayPlan.slotCompleted[slotId] ?? false;
    final completedAt = dayPlan.slotCompletedAt[slotId];

    return Card(
      color: AppTheme.cardBg,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppTheme.accent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Category tag & Eaten badge
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          slotName,
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isCompleted && completedAt != null)
                        _buildEatenTimeBadge(slotId, completedAt),
                    ],
                  ),
                ),
                // Actions: Log Food (AI) & Change
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => FoodLoggingDialog.show(
                        context,
                        date: _selectedDate,
                        slotId: slotId,
                        slotName: slotName,
                        initialMealName: meal.name,
                      ),
                      icon: const Icon(Icons.camera_alt_outlined, size: 14),
                      label: const Text('Log (AI)', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _pickMealForSlot(context, _selectedDate, slotId, slotName),
                      icon: const Icon(Icons.swap_horiz, size: 14),
                      label: const Text('Change', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Meal Checkbox & Name
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: isCompleted,
                  activeColor: AppTheme.accent,
                  onChanged: (val) {
                    context.read<DietBloc>().add(
                      ToggleMealCompletion(
                        date: _selectedDate,
                        slotId: slotId,
                        isCompleted: val ?? false,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    meal.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),

            // Ingredient chips wrap
            if (meal.ingredients.isNotEmpty) ...[
              const SizedBox(height: 12),
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActualSlot(String slotId, String slotName, DayPlan dayPlan, {Meal? plannedMeal}) {
    final actualName = dayPlan.slotActualMealName[slotId] ?? plannedMeal?.name ?? 'Logged Meal';
    final calories = dayPlan.slotCalories[slotId] ?? 0.0;
    final protein = dayPlan.slotProtein[slotId] ?? 0.0;
    final fats = dayPlan.slotFats[slotId] ?? 0.0;
    final carbs = dayPlan.slotCarbs[slotId] ?? 0.0;
    final fiber = dayPlan.slotFiber[slotId] ?? 0.0;
    final userNote = dayPlan.slotUserNote[slotId];
    final completedAt = dayPlan.slotCompletedAt[slotId];
    final aiBreakdown = dayPlan.slotAiBreakdown[slotId];

    void openBreakdown() {
      MealNutritionBreakdownDialog.show(
        context,
        date: _selectedDate,
        slotId: slotId,
        slotName: slotName,
        mealName: actualName,
        calories: calories,
        protein: protein,
        fats: fats,
        carbs: carbs,
        fiber: fiber,
        userNote: userNote,
        aiBreakdown: aiBreakdown,
        completedAt: completedAt,
      );
    }

    return Card(
      color: const Color(0xFF1E293B),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFF10B981),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: openBreakdown,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'Logged',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          slotName,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (completedAt != null)
                          _buildEatenTimeBadge(slotId, completedAt),
                      ],
                    ),
                  ),
                  // Actions Menu / Re-log & Reset & Details
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 18),
                        tooltip: 'View Nutrition Breakdown',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: openBreakdown,
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 18),
                        color: const Color(0xFF0F172A),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (val) {
                          if (val == 'details') {
                            openBreakdown();
                          } else if (val == 'relog') {
                            FoodLoggingDialog.show(
                              context,
                              date: _selectedDate,
                              slotId: slotId,
                              slotName: slotName,
                              initialMealName: actualName,
                            );
                          } else if (val == 'reset') {
                            context.read<DietBloc>().add(
                                  ClearActualMeal(
                                    date: _selectedDate,
                                    slotId: slotId,
                                  ),
                                );
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'details',
                            child: Row(
                              children: [
                                Icon(Icons.analytics_outlined, color: Color(0xFF10B981), size: 16),
                                SizedBox(width: 8),
                                Text('View Breakdown', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'relog',
                            child: Row(
                              children: [
                                Icon(Icons.camera_alt_outlined, color: AppTheme.accent, size: 16),
                                SizedBox(width: 8),
                                Text('Re-log with AI', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'reset',
                            child: Row(
                              children: [
                                Icon(Icons.restart_alt, color: AppTheme.error, size: 16),
                                SizedBox(width: 8),
                                Text('Reset to Plan', style: TextStyle(color: AppTheme.error, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Actual Meal Name
              Text(
                actualName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (plannedMeal != null && plannedMeal.name != actualName) ...[
                const SizedBox(height: 2),
                Text(
                  'Planned: ${plannedMeal.name}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Macro summary chips row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildMacroChip('${calories.toStringAsFixed(0)} kcal', 'Calories', const Color(0xFFF59E0B))),
                    Expanded(child: _buildMacroChip('${protein.toStringAsFixed(1)}g', 'P', const Color(0xFFEF4444))),
                    Expanded(child: _buildMacroChip('${fats.toStringAsFixed(1)}g', 'F', const Color(0xFFEAB308))),
                    Expanded(child: _buildMacroChip('${carbs.toStringAsFixed(1)}g', 'C', const Color(0xFF3B82F6))),
                    Expanded(child: _buildMacroChip('${fiber.toStringAsFixed(1)}g', 'Fiber', const Color(0xFF10B981))),
                  ],
                ),
              ),

              if (userNote != null && userNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        userNote,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnacksSection(BuildContext context, MealSlotConfig slotConfig, DayPlan dayPlan, List<Meal> library) {
    final slotId = slotConfig.id;
    final slotName = slotConfig.name;

    final isActual = dayPlan.slotIsActual[slotId] ?? false;
    if (isActual) {
      return _buildActualSlot(slotId, slotName, dayPlan);
    }

    final mealIds = dayPlan.slotMeals[slotId] ?? [];

    if (mealIds.isEmpty) {
      return DashedContainer(
        color: const Color(0xFF475569),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                slotName,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => FoodLoggingDialog.show(
                      context,
                      date: _selectedDate,
                      slotId: slotId,
                      slotName: slotName,
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 14),
                    label: const Text('Log (AI)', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _pickSnackForSlot(context, _selectedDate, slotId, slotName),
                    icon: const Icon(Icons.add, size: 14),
                    label: Text('Add $slotName', style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cardBg,
                      foregroundColor: AppTheme.accent,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final isCompleted = dayPlan.slotCompleted[slotId] ?? false;
    final completedAt = dayPlan.slotCompletedAt[slotId];

    return Card(
      color: AppTheme.cardBg,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: isCompleted,
                      activeColor: AppTheme.accent,
                      onChanged: (val) {
                        context.read<DietBloc>().add(
                          ToggleMealCompletion(
                            date: _selectedDate,
                            slotId: slotId,
                            isCompleted: val ?? false,
                          ),
                        );
                      },
                    ),
                    Text(
                      slotName,
                      style: const TextStyle(
                        color: AppTheme.accentMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (isCompleted && completedAt != null) ...[
                      const SizedBox(width: 8),
                      _buildEatenTimeBadge(slotId, completedAt),
                    ],
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => FoodLoggingDialog.show(
                        context,
                        date: _selectedDate,
                        slotId: slotId,
                        slotName: slotName,
                      ),
                      icon: const Icon(Icons.camera_alt_outlined, size: 14),
                      label: const Text('Log (AI)', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _pickSnackForSlot(context, _selectedDate, slotId, slotName),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mealIds.length,
              itemBuilder: (context, index) {
                final mealId = mealIds[index];
                final snackMeal = library.firstWhere(
                  (m) => m.id == mealId,
                  orElse: () => Meal(name: 'Unknown Snack', category: 'Snack', ingredients: []),
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              snackMeal.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (snackMeal.ingredients.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                snackMeal.ingredients.join(', '),
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                        onPressed: () {
                          context.read<DietBloc>().add(
                                RemoveSnackFromSlot(date: _selectedDate, slotId: slotId, index: index),
                              );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyMacroSummary(DayPlan dayPlan) {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalFats = 0.0;
    double totalCarbs = 0.0;
    double totalFiber = 0.0;
    int loggedMealsCount = 0;

    dayPlan.slotIsActual.forEach((slotId, isActual) {
      if (isActual) {
        loggedMealsCount++;
        totalCalories += dayPlan.slotCalories[slotId] ?? 0.0;
        totalProtein += dayPlan.slotProtein[slotId] ?? 0.0;
        totalFats += dayPlan.slotFats[slotId] ?? 0.0;
        totalCarbs += dayPlan.slotCarbs[slotId] ?? 0.0;
        totalFiber += dayPlan.slotFiber[slotId] ?? 0.0;
      }
    });

    if (loggedMealsCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart_outline, size: 16, color: AppTheme.accent),
                  SizedBox(width: 6),
                  Text(
                    'Daily Actual Nutrition',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Text(
                '$loggedMealsCount logged',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMacroChip('${totalCalories.toStringAsFixed(0)} kcal', 'Calories', const Color(0xFFF59E0B))),
              Expanded(child: _buildMacroChip('${totalProtein.toStringAsFixed(1)}g', 'Protein', const Color(0xFFEF4444))),
              Expanded(child: _buildMacroChip('${totalFats.toStringAsFixed(1)}g', 'Fats', const Color(0xFFEAB308))),
              Expanded(child: _buildMacroChip('${totalCarbs.toStringAsFixed(1)}g', 'Carbs', const Color(0xFF3B82F6))),
              Expanded(child: _buildMacroChip('${totalFiber.toStringAsFixed(1)}g', 'Fiber', const Color(0xFF10B981))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip(String value, String label, Color color) {
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

  Widget _buildPlannerBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Scrolling Week selector
        _buildWeekDaySelector(),
        const SizedBox(height: 8),

        // Last Meal Banner
        BlocBuilder<DietBloc, DietState>(
          builder: (context, state) => _buildLastMealBanner(state),
        ),

        // Daily Actual Nutrition Macro Summary
        BlocBuilder<DietBloc, DietState>(
          builder: (context, state) {
            final dayPlan = state.dayPlans.firstWhere(
              (p) => _isSameDate(p.date, _selectedDate),
              orElse: () => DayPlan(date: _selectedDate, slotMeals: const {}),
            );
            return _buildDailyMacroSummary(dayPlan);
          },
        ),
        const SizedBox(height: 4),

        // Divider
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(color: Color(0xFF334155), height: 1),
        ),
        const SizedBox(height: 12),

        // 2. Selected Day Planner Slots
        Expanded(
          child: BlocBuilder<DietBloc, DietState>(
            builder: (context, state) {
              final dayPlan = state.dayPlans.firstWhere(
                (p) => _isSameDate(p.date, _selectedDate),
                orElse: () => DayPlan(date: _selectedDate, slotMeals: const {}),
              );

              Meal? getMeal(String? id) {
                if (id == null) return null;
                return state.mealsLibrary.firstWhere(
                  (m) => m.id == id,
                  orElse: () => Meal(name: 'Unknown', category: 'Breakfast', ingredients: []),
                );
              }

              // Load active slots configuration (isEnabled sorted by orderIndex)
              final activeSlots = state.mealSlots.where((s) => s.isEnabled).toList()
                ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

              if (activeSlots.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.playlist_add_check_outlined,
                          size: 72,
                          color: Color(0xFF475569),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No active slots',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enable meal slots in Slots Settings to start scheduling your menu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SlotsManagementScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: AppTheme.background,
                          ),
                          child: const Text('Manage Slots'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: activeSlots.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final slotConfig = activeSlots[index];
                  
                  // Check if this slot should be treated as snack-list based (id contains 'snack' or equals 'snacks')
                  final isSnack = slotConfig.id == '00000000-0000-0000-0000-000000000004' || slotConfig.id == 'snacks' || slotConfig.id.contains('snack') || slotConfig.name.toLowerCase().contains('snack');

                  if (isSnack) {
                    return _buildSnacksSection(context, slotConfig, dayPlan, state.mealsLibrary);
                  } else {
                    final mealIds = dayPlan.slotMeals[slotConfig.id] ?? [];
                    final mealId = mealIds.isNotEmpty ? mealIds.first : null;
                    final meal = getMeal(mealId);

                    return meal == null
                        ? _buildEmptySlot(slotConfig.id, slotConfig.name, dayPlan)
                        : _buildSelectedSlot(slotConfig.id, slotConfig.name, meal, dayPlan);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final userEmail = Supabase.instance.client.auth.currentUser?.email ?? 'Unknown User';
        return Dialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // User Email Card
                Card(
                  color: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle_outlined, color: AppTheme.accent, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Signed in as:',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              ),
                              Text(
                                userEmail,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Manage Slots Option
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_outlined, color: AppTheme.textPrimary),
                  title: const Text('Meal Slots Settings', style: TextStyle(color: AppTheme.textPrimary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SlotsManagementScreen(),
                      ),
                    );
                  },
                ),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 16),
                // Sign Out Button
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog
                    await Supabase.instance.client.auth.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: AppTheme.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _currentIndex == 0
          ? AppBar(
              title: const Text('PlateMate Daily'),
              centerTitle: true,
              backgroundColor: AppTheme.background,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Settings',
                  onPressed: () => _showSettingsDialog(context),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildPlannerBody(),
            const MealsLibraryScreen(isTab: true),
            const GroceryListScreen(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppTheme.cardBg,
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: AppTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Planner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flatware),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Grocery',
          ),
        ],
      ),
    );
  }
}
