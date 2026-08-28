import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../blocs/diet_bloc.dart';
import '../../core/theme.dart';
import '../../models/meal.dart';
import '../../models/day_plan.dart';

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final _textController = TextEditingController();
  String _selectedRange = 'This Week';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _getRangeDays() {
    if (_selectedRange == 'Today') return 1;
    if (_selectedRange == 'Next 3 Days') return 3;
    return 7;
  }

  List<String> _aggregatePlannedIngredients(DietState state) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Aggregate for the selected time range
    final nextDays = List.generate(_getRangeDays(), (index) => today.add(Duration(days: index)));
    
    final List<String> rawIngredients = [];

    for (var date in nextDays) {
      final dayPlan = state.dayPlans.firstWhere(
        (p) => _isSameDate(p.date, date),
        orElse: () => DayPlan(date: date, slotMeals: const {}),
      );

      Meal? getMeal(String? id) {
        if (id == null) return null;
        return state.mealsLibrary.firstWhere(
          (m) => m.id == id,
          orElse: () => Meal(name: 'Unknown', category: 'Breakfast', ingredients: []),
        );
      }

      final List<Meal?> meals = [];
      dayPlan.slotMeals.forEach((slotId, mealIds) {
        final isEnabled = state.mealSlots.any((s) => s.id == slotId && s.isEnabled);
        if (isEnabled) {
          for (var mealId in mealIds) {
            meals.add(getMeal(mealId));
          }
        }
      });

      for (var meal in meals) {
        if (meal != null && meal.name != 'Unknown') {
          for (var ing in meal.ingredients) {
            final ingLower = ing.toLowerCase().trim();
            if (!dayPlan.clearedIngredients.contains(ingLower)) {
              rawIngredients.add(ing);
            }
          }
        }
      }
    }

    return rawIngredients;
  }

  void _addManualItem() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      context.read<DietBloc>().add(AddManualGroceryItem(text));
      _textController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _handleShare(BuildContext context, Map<String, String> groupedList, DietState state) async {
    try {
      if (groupedList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grocery list is empty'),
            backgroundColor: AppTheme.cardBg,
          ),
        );
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('🛒 PlateMate Grocery List:\n');
      groupedList.forEach((key, value) {
        final isBought = state.crossedIngredients.contains(key);
        final status = isBought ? '✅ ' : '⬜ ';
        buffer.writeln('$status$value');
      });

      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      await Share.share(
        buffer.toString(),
        subject: 'PlateMate Grocery List',
        sharePositionOrigin: origin,
      );
    } catch (e, st) {
      debugPrint('PlateMate Share Error: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share error: $e'),
            backgroundColor: AppTheme.cardBg,
          ),
        );
      }
    }
  }

  void _confirmClearChecked(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text(
            'Clear Purchased Items?',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: const Text(
            'This will remove all checked items from your grocery list.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<DietBloc>().add(ClearCheckedGrocery());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Checked items cleared'),
                    backgroundColor: AppTheme.accent,
                  ),
                );
              },
              child: const Text(
                'Clear',
                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: BlocBuilder<DietBloc, DietState>(
          builder: (context, state) {
            // 1. Fetch and aggregate ingredients from active scheduled plans for selected range
            final plannedIngs = _aggregatePlannedIngredients(state);

            // 2. Combine duplicate ingredients case-insensitively
            final Map<String, String> groupedList = {}; // key: lowercase, value: original casing
            
            for (var ing in plannedIngs) {
              final key = ing.toLowerCase().trim();
              if (key.isNotEmpty && !groupedList.containsKey(key)) {
                groupedList[key] = ing.trim();
              }
            }

            // 3. Merge manual extra items
            for (var item in state.manualGroceryItems) {
              final key = item.toLowerCase().trim();
              if (key.isNotEmpty && !groupedList.containsKey(key)) {
                groupedList[key] = item.trim();
              }
            }

            final finalKeys = groupedList.keys.toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Title and Share / Clear actions
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Grocery List',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share),
                            tooltip: 'Share List',
                            onPressed: () => _handleShare(context, groupedList, state),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: 'Clear Checked Items',
                            onPressed: () {
                              if (finalKeys.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Grocery list is empty'),
                                    backgroundColor: AppTheme.cardBg,
                                  ),
                                );
                              } else {
                                _confirmClearChecked(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Range Selector filter chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Wrap(
                    spacing: 8,
                    children: ['Today', 'Next 3 Days', 'This Week'].map((range) {
                      final isSelected = _selectedRange == range;
                      return ChoiceChip(
                        label: Text(range),
                        selected: isSelected,
                        selectedColor: AppTheme.accent.withValues(alpha: 0.15),
                        checkmarkColor: AppTheme.accent,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedRange = range;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Manual item input form
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            hintText: 'Add extra item...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: const TextStyle(color: AppTheme.textPrimary),
                          onFieldSubmitted: (_) => _addManualItem(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addManualItem,
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
                ),

                // Aggregation range note
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Aggregated from all active slots for $_selectedRange.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Checklist Items
                Expanded(
                  child: finalKeys.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: finalKeys.length,
                          itemBuilder: (context, index) {
                            final key = finalKeys[index];
                            final displayName = groupedList[key]!;
                            final isCrossed = state.crossedIngredients.contains(key);
                            final isManual = state.manualGroceryItems.any((e) => e.toLowerCase().trim() == key);

                            return Card(
                              color: AppTheme.cardBg,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isCrossed
                                      ? const Color(0xFF334155)
                                      : AppTheme.accent.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: CheckboxListTile(
                                value: isCrossed,
                                activeColor: AppTheme.accent,
                                checkColor: AppTheme.background,
                                title: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isCrossed ? AppTheme.textSecondary : AppTheme.textPrimary,
                                    decoration: isCrossed ? TextDecoration.lineThrough : null,
                                    fontWeight: isCrossed ? FontWeight.normal : FontWeight.w500,
                                  ),
                                ),
                                subtitle: isManual
                                    ? const Text(
                                        'Manual Item',
                                        style: TextStyle(color: AppTheme.accentMuted, fontSize: 11),
                                      )
                                    : null,
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                onChanged: (_) {
                                  context.read<DietBloc>().add(ToggleGroceryItem(key));
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 72,
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Your grocery list is empty',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Schedule meals for $_selectedRange or add extra items above to generate your checklist.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
