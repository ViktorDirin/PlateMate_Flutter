import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/diet_bloc.dart';
import '../../core/theme.dart';
import 'diet_detail_screen.dart';

class DietListScreen extends StatefulWidget {
  const DietListScreen({super.key});

  @override
  State<DietListScreen> createState() => _DietListScreenState();
}

class _DietListScreenState extends State<DietListScreen> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Cold start bypass check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<DietBloc>().state;
      if (state.defaultDietId != null) {
        final defaultDietExists = state.diets.any((d) => d.id == state.defaultDietId);
        if (defaultDietExists) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DietDetailScreen(dietId: state.defaultDietId!),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showAddDietModal() {
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
                'Новая диета',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Название диеты',
                  hintText: 'например, Диета Vik',
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isNotEmpty) {
                    context.read<DietBloc>().add(AddDiet(name));
                    _nameController.clear();
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
                  'Создать',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
        title: const Text('PlateMate'),
        actions: [
          BlocBuilder<DietBloc, DietState>(
            builder: (context, state) {
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

              return IconButton(
                icon: Icon(syncIcon, color: syncColor),
                onPressed: () {
                  context.read<DietBloc>().add(SyncWithCloud());
                },
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<DietBloc, DietState>(
        builder: (context, state) {
          if (state.diets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 64,
                      color: AppTheme.accent.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Список диет пуст',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Создайте свой первый план питания, чтобы начать отслеживание.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showAddDietModal,
                      icon: const Icon(Icons.add),
                      label: const Text('Создать диету'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.background,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: state.diets.length,
            itemBuilder: (context, index) {
              final diet = state.diets[index];
              final isDefault = diet.id == state.defaultDietId;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DietDetailScreen(dietId: diet.id),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                diet.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontSize: 20,
                                      color: AppTheme.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${diet.meals.length} блюд запланировано',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isDefault ? Icons.star : Icons.star_border,
                            color: isDefault ? AppTheme.accent : AppTheme.textSecondary,
                            size: 28,
                          ),
                          onPressed: () {
                            context.read<DietBloc>().add(SetDefaultDiet(diet.id));
                          },
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
      floatingActionButton: BlocBuilder<DietBloc, DietState>(
        builder: (context, state) {
          if (state.diets.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: _showAddDietModal,
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.background,
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}
