import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../blocs/diet_bloc.dart';
import '../../core/theme.dart';
import '../../models/meal_slot_config.dart';

class SlotsManagementScreen extends StatefulWidget {
  const SlotsManagementScreen({super.key});

  @override
  State<SlotsManagementScreen> createState() => _SlotsManagementScreenState();
}

class _SlotsManagementScreenState extends State<SlotsManagementScreen> {
  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Sign Out'),
          content: const Text(
            'Are you sure you want to sign out from your PlateMate account?',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                Navigator.pop(context);
                await Supabase.instance.client.auth.signOut();
              },
              child: const Text('Sign Out', style: TextStyle(color: AppTheme.error)),
            ),
          ],
        );
      },
    );
  }

  void _showAddSlotDialog(BuildContext context, List<MealSlotConfig> existing) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Add Meal Slot'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g., Pre-workout Meal',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  // Check name collision case-insensitively
                  if (existing.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('A slot with this name already exists.'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                    return;
                  }
                  final newSlot = MealSlotConfig(
                    id: const Uuid().v4(),
                    name: name,
                    orderIndex: existing.length,
                    isEnabled: true,
                  );
                  context.read<DietBloc>().add(AddMealSlot(newSlot));
                  Navigator.pop(context);
                }
              },
              child: const Text('Add', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, MealSlotConfig slot) {
    final controller = TextEditingController(text: slot.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Rename Meal Slot'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter new name',
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  context.read<DietBloc>().add(
                        UpdateMealSlot(slot.copyWith(name: name)),
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('Rename', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, MealSlotConfig slot) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: const Text('Delete Slot'),
          content: Text(
            'Are you sure you want to delete "${slot.name}"? '
            'All scheduled meals in this slot will be cleared from your calendar.',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                context.read<DietBloc>().add(DeleteMealSlot(slot.id));
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
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
      appBar: AppBar(
        title: const Text('Meal Slots Settings'),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.error),
            tooltip: 'Sign Out',
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<DietBloc, DietState>(
          builder: (context, state) {
            final slots = List<MealSlotConfig>.from(state.mealSlots)
              ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

            if (slots.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.settings_outlined, size: 72, color: Color(0xFF475569)),
                    const SizedBox(height: 16),
                    const Text(
                      'No meal slots defined',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _showAddSlotDialog(context, slots),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.background,
                      ),
                      child: const Text('Add Meal Slot'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                  child: Card(
                    color: AppTheme.cardBg,
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
                                  Supabase.instance.client.auth.currentUser?.email ?? 'Unknown User',
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
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    'Drag handles on the right to reorder. Custom slots can be renamed, enabled, or deleted.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: slots.length,
                    itemBuilder: (context, index) {
                      final slot = slots[index];

                      return Card(
                        key: ValueKey(slot.id),
                        color: AppTheme.cardBg,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF334155), width: 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(
                            slot.name,
                            style: TextStyle(
                              color: slot.isEnabled ? AppTheme.textPrimary : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            slot.isEnabled ? 'Active' : 'Disabled',
                            style: TextStyle(
                              color: slot.isEnabled ? AppTheme.accentMuted : AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 20),
                                onPressed: () => _showRenameDialog(context, slot),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                                onPressed: () => _confirmDelete(context, slot),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: slot.isEnabled,
                                activeThumbColor: AppTheme.accent,
                                inactiveThumbColor: AppTheme.textSecondary,
                                onChanged: (val) {
                                  context.read<DietBloc>().add(
                                        UpdateMealSlot(slot.copyWith(isEnabled: val)),
                                      );
                                },
                              ),
                              const SizedBox(width: 8),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      context.read<DietBloc>().add(
                            ReorderMealSlots(oldIndex: oldIndex, newIndex: newIndex),
                          );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final existing = context.read<DietBloc>().state.mealSlots;
          _showAddSlotDialog(context, existing);
        },
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.background,
        child: const Icon(Icons.add),
      ),
    );
  }
}
