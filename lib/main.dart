import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'blocs/diet_bloc.dart';
import 'core/theme.dart';
import 'models/meal.dart';
import 'models/day_plan.dart';
import 'models/meal_slot_config.dart';
import 'services/meal_photo_service.dart';
import 'services/report_export_service.dart';
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
  DateTime _focusedWeekDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
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

  List<DateTime> _generateWeekForDate(DateTime date) {
    final currentWeekday = date.weekday; // 1 = Monday, 7 = Sunday
    final startOfWeek = date.subtract(Duration(days: currentWeekday - 1));
    return List.generate(7, (index) => DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day + index,
    ));
  }

  void _goToPreviousWeek() {
    setState(() {
      _focusedWeekDate = _focusedWeekDate.subtract(const Duration(days: 7));
    });
  }

  void _goToNextWeek() {
    setState(() {
      _focusedWeekDate = _focusedWeekDate.add(const Duration(days: 7));
    });
  }

  void _goToToday() {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    setState(() {
      _selectedDate = today;
      _focusedWeekDate = today;
    });
  }

  Future<void> _pickCustomDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: AppTheme.darkTheme.copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accent,
              onPrimary: AppTheme.background,
              surface: Color(0xFF1E293B),
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final normalized = DateTime(picked.year, picked.month, picked.day);
      setState(() {
        _selectedDate = normalized;
        _focusedWeekDate = normalized;
      });
    }
  }

  void _pickMealForSlot(BuildContext context, DateTime date, String slotId, String slotName) {
    // Attempt to map custom slot name to standard category filters (supporting English and Russian)
    final cleanName = slotName.toLowerCase();
    String? categoryFilter;
    if (cleanName.contains('breakfast') || cleanName.contains('завтрак') || cleanName.contains('утрен')) {
      categoryFilter = 'Breakfast';
    } else if (cleanName.contains('lunch') || cleanName.contains('обед') || cleanName.contains('day')) {
      categoryFilter = 'Lunch';
    } else if (cleanName.contains('dinner') || cleanName.contains('ужин') || cleanName.contains('вечер') || cleanName.contains('supper')) {
      categoryFilter = 'Dinner';
    } else if (cleanName.contains('snack') || cleanName.contains('перекус') || cleanName.contains('полдник')) {
      categoryFilter = 'Snack';
    } else {
      categoryFilter = 'All';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealsLibraryScreen(
          initialCategory: categoryFilter,
          targetSlotId: slotId,
          targetSlotName: slotName,
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
          initialCategory: 'Snack',
          targetSlotId: slotId,
          targetSlotName: slotName,
          onMealPicked: (mealId) {
            context.read<DietBloc>().add(
                  AddSnackToSlot(date: date, slotId: slotId, mealId: mealId),
                );
          },
        ),
      ),
    );
  }

  void _showEnlargedPhotoDialog(BuildContext context, String photoUrl, String mealName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        mealName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Enlarged Image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: MealPhotoService.buildMealImage(
                  photoUrl: photoUrl,
                  fit: BoxFit.contain,
                  placeholder: Container(
                    height: 220,
                    color: const Color(0xFF0F172A),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    ),
                  ),
                  errorWidget: Container(
                    height: 220,
                    color: const Color(0xFF0F172A),
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 48, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadSlotPhoto(BuildContext context, DateTime date, String slotId) async {
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

      if (photo == null || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading meal photo...'),
          backgroundColor: Color(0xFF0F172A),
          duration: Duration(seconds: 2),
        ),
      );

      final uploadedUrl = await MealPhotoService.uploadMealPhoto(
        image: photo,
        slotId: slotId,
      );

      if (!context.mounted) return;

      if (uploadedUrl != null) {
        context.read<DietBloc>().add(
              UpdateSlotPhoto(
                date: date,
                slotId: slotId,
                photoUrl: uploadedUrl,
              ),
            );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Photo updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload photo. Please check your connection.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating photo: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
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
    final weekDays = _generateWeekForDate(_focusedWeekDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isViewingTodayWeek = weekDays.any((d) => _isSameDate(d, today));
    final isSelectedToday = _isSameDate(_selectedDate, today);

    // Formatted header string e.g. "September 2026" or "Sep - Oct 2026" if crossing months
    final firstDay = weekDays.first;
    final lastDay = weekDays.last;
    final String monthHeader = firstDay.month == lastDay.month
        ? DateFormat('MMMM yyyy').format(firstDay)
        : '${DateFormat('MMM').format(firstDay)} – ${DateFormat('MMM yyyy').format(lastDay)}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Navigation Bar: [ < ] [ Month Year (pick) ] [ Today ] [ > ]
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppTheme.accent, size: 20),
                tooltip: 'Previous Week',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _goToPreviousWeek,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: () => _pickCustomDate(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            monthHeader,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.calendar_month_outlined, size: 13, color: AppTheme.accent),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (!isSelectedToday || !isViewingTodayWeek) ...[
                InkWell(
                  onTap: _goToToday,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppTheme.accent, size: 20),
                tooltip: 'Next Week',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _goToNextWeek,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 7-day strip with horizontal drag/swipe support
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -200) {
                  _goToNextWeek();
                } else if (details.primaryVelocity! > 200) {
                  _goToPreviousWeek();
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weekDays.map((date) {
                final isSelected = _isSameDate(date, _selectedDate);
                final isDayToday = _isSameDate(date, today);
                final weekdayStr = DateFormat('E').format(date); // Mon, Tue...
                final dayStr = DateFormat('d').format(date); // 26, 27...

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                        _focusedWeekDate = date;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accent.withValues(alpha: 0.15)
                            : (isDayToday
                                ? const Color(0xFF0F172A)
                                : Colors.transparent),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accent
                              : (isDayToday
                                  ? AppTheme.accent.withValues(alpha: 0.4)
                                  : const Color(0xFF334155)),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            weekdayStr,
                            style: TextStyle(
                              color: isSelected
                                  ? AppTheme.accent
                                  : (isDayToday ? AppTheme.accent : AppTheme.textSecondary),
                              fontSize: 11,
                              fontWeight: (isSelected || isDayToday) ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dayStr,
                            style: TextStyle(
                              color: isSelected
                                  ? AppTheme.accent
                                  : AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isDayToday && !isSelected) ...[
                            const SizedBox(height: 2),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                slotName,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: () => _pickMealForSlot(context, _selectedDate, slotId, slotName),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardBg,
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                // Actions: Log Food (AI), Change, and Remove
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
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary, size: 18),
                      tooltip: 'Remove Meal',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        context.read<DietBloc>().add(
                              ScheduleMealToSlot(
                                date: _selectedDate,
                                slotId: slotId,
                                mealId: null,
                              ),
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Cleared "$slotName"'),
                            backgroundColor: const Color(0xFF0F172A),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
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

    final photoUrl = dayPlan.slotPhotoUrl[slotId];

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
        photoUrl: photoUrl,
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
                          } else if (val == 'photo') {
                            _pickAndUploadSlotPhoto(context, _selectedDate, slotId);
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Cleared "$slotName"'),
                                backgroundColor: const Color(0xFF0F172A),
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
                          PopupMenuItem(
                            value: 'photo',
                            child: Row(
                              children: [
                                Icon(
                                  photoUrl != null ? Icons.photo_camera_outlined : Icons.add_a_photo_outlined,
                                  color: AppTheme.accent,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  photoUrl != null ? 'Change Photo' : 'Attach Photo',
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                ),
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
                                Icon(Icons.delete_outline, color: AppTheme.error, size: 16),
                                SizedBox(width: 8),
                                Text('Clear Slot', style: TextStyle(color: AppTheme.error, fontSize: 13)),
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

              // Actual Meal Name & Photo Thumbnail
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      ],
                    ),
                  ),
                  if (photoUrl != null && photoUrl.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _showEnlargedPhotoDialog(context, photoUrl, actualName),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 54,
                          height: 54,
                          color: const Color(0xFF0F172A),
                          child: MealPhotoService.buildMealImage(
                            photoUrl: photoUrl,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorWidget: const Center(
                              child: Icon(Icons.broken_image_outlined, size: 20, color: AppTheme.textSecondary),
                            ),
                            placeholder: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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

  void _showEditDailyCalorieTargetDialog(BuildContext context, double currentTarget) {
    final controller = TextEditingController(text: currentTarget.round().toString());
    final presets = [1600, 1800, 2000, 2200, 2500, 3000];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.track_changes, color: AppTheme.accent, size: 18),
                              ),
                              const SizedBox(width: 10),
                              const Flexible(
                                child: Text(
                                  'Daily Calorie Target',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Set your daily energy budget for diet planning and tracking.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Daily Goal (kcal)',
                        labelStyle: const TextStyle(color: AppTheme.accent),
                        suffixText: 'kcal',
                        suffixStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Quick Presets:',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: presets.map((p) {
                        final isSelected = controller.text == p.toString();
                        return InkWell(
                          onTap: () {
                            controller.text = p.toString();
                            setDialogState(() {});
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.accent
                                    : const Color(0xFF334155),
                              ),
                            ),
                            child: Text(
                              '$p kcal',
                              style: TextStyle(
                                color: isSelected
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final parsed = double.tryParse(controller.text.trim());
                              if (parsed != null && parsed > 0) {
                                context.read<DietBloc>().add(SetDailyCalorieTarget(parsed));
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✓ Daily target set to ${parsed.round()} kcal'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: AppTheme.background,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Save Target',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDailyMacroSummary(DayPlan dayPlan, double dailyTarget) {
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalFats = 0.0;
    double totalCarbs = 0.0;
    double totalFiber = 0.0;

    dayPlan.slotIsActual.forEach((slotId, isActual) {
      if (isActual) {
        totalCalories += dayPlan.slotCalories[slotId] ?? 0.0;
        totalProtein += dayPlan.slotProtein[slotId] ?? 0.0;
        totalFats += dayPlan.slotFats[slotId] ?? 0.0;
        totalCarbs += dayPlan.slotCarbs[slotId] ?? 0.0;
        totalFiber += dayPlan.slotFiber[slotId] ?? 0.0;
      }
    });

    final target = dailyTarget > 0 ? dailyTarget : 2000.0;
    final isOver = totalCalories > target;
    final diff = (target - totalCalories).abs();
    final progress = (totalCalories / target).clamp(0.0, 1.0);
    final progressColor = isOver ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Daily Goal Title & Target Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.track_changes, size: 15, color: AppTheme.accent),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Daily Goal',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: InkWell(
                  onTap: () => _showEditDailyCalorieTargetDialog(context, target),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Target: ${target.round()} kcal',
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.edit_outlined, size: 11, color: AppTheme.accent),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Middle Row: Calories "900 / 2000 kcal" & Remaining status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: InkWell(
                  onTap: () => _showEditDailyCalorieTargetDialog(context, target),
                  borderRadius: BorderRadius.circular(4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${totalCalories.round()}',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: ' / ${target.round()} kcal',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isOver
                      ? '${diff.round()} kcal over'
                      : '${diff.round()} kcal remaining',
                  style: TextStyle(
                    color: isOver ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF334155),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 12),

          // Macro Row
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
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

        // Daily Actual Nutrition Macro Summary & Calorie Target Progress
        BlocBuilder<DietBloc, DietState>(
          builder: (context, state) {
            final dayPlan = state.dayPlans.firstWhere(
              (p) => _isSameDate(p.date, _selectedDate),
              orElse: () => DayPlan(date: _selectedDate, slotMeals: const {}),
            );
            return _buildDailyMacroSummary(dayPlan, state.dailyCalorieTarget);
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
        String userEmail = 'PlateMate User';
        try {
          userEmail = Supabase.instance.client.auth.currentUser?.email ?? 'PlateMate User';
        } catch (_) {}
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
                // Daily Calorie Target Option
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.track_changes, color: AppTheme.accent),
                  title: const Text('Daily Calorie Target', style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: BlocBuilder<DietBloc, DietState>(
                    builder: (context, state) => Text(
                      '${state.dailyCalorieTarget.round()} kcal',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () {
                    final currentTarget = context.read<DietBloc>().state.dailyCalorieTarget;
                    _showEditDailyCalorieTargetDialog(context, currentTarget);
                  },
                ),
                const Divider(color: Color(0xFF334155)),
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
                // Export HTML Nutrition Report Option
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.summarize_outlined, color: AppTheme.accent),
                  title: const Text('Export Nutrition Report', style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: const Text(
                    'Generate & share responsive HTML diet report',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () {
                    Navigator.pop(context); // Close settings dialog
                    _showExportReportDialog(context);
                  },
                ),
                const Divider(color: Color(0xFF334155)),
                const SizedBox(height: 16),
                // Sign Out Button
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog
                    try {
                      await Supabase.instance.client.auth.signOut();
                    } catch (_) {}
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

  void _showExportReportDialog(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime startDate = today.subtract(const Duration(days: 6));
    DateTime endDate = today;
    String selectedPreset = 'Last 7 Days';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final formattedRange =
                '${DateFormat('MMM d, yyyy').format(startDate)} – ${DateFormat('MMM d, yyyy').format(endDate)}';
            final totalDays = endDate.difference(startDate).inDays + 1;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
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
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.summarize_outlined, color: AppTheme.accent, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Flexible(
                                child: Text(
                                  'Export HTML Report',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
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
                    const Text(
                      'Generate a self-contained responsive HTML report of your nutrition, meal logs, and macro summaries.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Date Range:',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildRangePresetChip(
                          label: 'Last 7 Days',
                          isSelected: selectedPreset == 'Last 7 Days',
                          onTap: () {
                            setDialogState(() {
                              selectedPreset = 'Last 7 Days';
                              startDate = today.subtract(const Duration(days: 6));
                              endDate = today;
                            });
                          },
                        ),
                        _buildRangePresetChip(
                          label: 'Last 14 Days',
                          isSelected: selectedPreset == 'Last 14 Days',
                          onTap: () {
                            setDialogState(() {
                              selectedPreset = 'Last 14 Days';
                              startDate = today.subtract(const Duration(days: 13));
                              endDate = today;
                            });
                          },
                        ),
                        _buildRangePresetChip(
                          label: 'Last 30 Days',
                          isSelected: selectedPreset == 'Last 30 Days',
                          onTap: () {
                            setDialogState(() {
                              selectedPreset = 'Last 30 Days';
                              startDate = today.subtract(const Duration(days: 29));
                              endDate = today;
                            });
                          },
                        ),
                        _buildRangePresetChip(
                          label: 'Current Month',
                          isSelected: selectedPreset == 'Current Month',
                          onTap: () {
                            setDialogState(() {
                              selectedPreset = 'Current Month';
                              startDate = DateTime(today.year, today.month, 1);
                              final nextMonth = DateTime(today.year, today.month + 1, 1);
                              endDate = nextMonth.subtract(const Duration(days: 1));
                            });
                          },
                        ),
                        _buildRangePresetChip(
                          label: 'Custom...',
                          isSelected: selectedPreset == 'Custom',
                          onTap: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              initialDateRange: DateTimeRange(start: startDate, end: endDate),
                              builder: (context, child) {
                                return Theme(
                                  data: AppTheme.darkTheme.copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: AppTheme.accent,
                                      onPrimary: AppTheme.background,
                                      surface: Color(0xFF1E293B),
                                      onSurface: AppTheme.textPrimary,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedPreset = 'Custom';
                                startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
                                endDate = DateTime(picked.end.year, picked.end.month, picked.end.day);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Selected Range Info Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, color: AppTheme.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formattedRange,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '$totalDays ${totalDays == 1 ? "day" : "days"} included in report',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final state = context.read<DietBloc>().state;
                              String? userEmail;
                              try {
                                userEmail = Supabase.instance.client.auth.currentUser?.email;
                              } catch (_) {}
                              Navigator.pop(ctx);
                              await ReportExportService.exportAndShareReport(
                                context: context,
                                state: state,
                                startDate: startDate,
                                endDate: endDate,
                                userEmail: userEmail,
                              );
                            },
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text(
                              'Share Report',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: AppTheme.background,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRangePresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.accent : const Color(0xFF334155),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
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
