import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../blocs/diet_bloc.dart';
import '../../core/theme.dart';
import '../../services/food_analysis_service.dart';
import '../../services/meal_photo_service.dart';

class FoodLoggingDialog extends StatefulWidget {
  final DateTime date;
  final String slotId;
  final String slotName;
  final String? initialMealName;

  const FoodLoggingDialog({
    super.key,
    required this.date,
    required this.slotId,
    required this.slotName,
    this.initialMealName,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    required String slotId,
    required String slotName,
    String? initialMealName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: FoodLoggingDialog(
          date: date,
          slotId: slotId,
          slotName: slotName,
          initialMealName: initialMealName,
        ),
      ),
    );
  }

  @override
  State<FoodLoggingDialog> createState() => _FoodLoggingDialogState();
}

class _FoodLoggingDialogState extends State<FoodLoggingDialog> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  final TextEditingController _noteController = TextEditingController();

  // Review step controllers
  final TextEditingController _mealNameController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatsController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fiberController = TextEditingController();

  bool _isAnalyzing = false;
  FoodAnalysisResult? _analysisResult;

  bool _isAddingIngredient = false;
  final TextEditingController _addNameController = TextEditingController();
  final TextEditingController _addWeightController = TextEditingController(text: '100');

  @override
  void dispose() {
    _noteController.dispose();
    _mealNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatsController.dispose();
    _carbsController.dispose();
    _fiberController.dispose();
    _addNameController.dispose();
    _addWeightController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final name = _addNameController.text.trim();
    if (name.isEmpty) return;

    final grams = double.tryParse(_addWeightController.text.trim()) ?? 100.0;

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

    final currentItems = List<FoodAnalysisItem>.from(_analysisResult?.items ?? []);
    currentItems.add(newItem);

    final curCal = (double.tryParse(_caloriesController.text.trim()) ?? _analysisResult?.calories ?? 0.0) + itemCal;
    final curP = (double.tryParse(_proteinController.text.trim()) ?? _analysisResult?.protein ?? 0.0) + itemP;
    final curF = (double.tryParse(_fatsController.text.trim()) ?? _analysisResult?.fats ?? 0.0) + itemF;
    final curC = (double.tryParse(_carbsController.text.trim()) ?? _analysisResult?.carbs ?? 0.0) + itemC;
    final curFiber = (double.tryParse(_fiberController.text.trim()) ?? _analysisResult?.fiber ?? 0.0) + itemFiber;

    setState(() {
      _caloriesController.text = curCal.toStringAsFixed(0);
      _proteinController.text = curP.toStringAsFixed(1);
      _fatsController.text = curF.toStringAsFixed(1);
      _carbsController.text = curC.toStringAsFixed(1);
      _fiberController.text = curFiber.toStringAsFixed(1);

      _analysisResult = FoodAnalysisResult(
        mealName: _mealNameController.text.trim().isNotEmpty
            ? _mealNameController.text.trim()
            : (_analysisResult?.mealName ?? 'Logged Meal'),
        calories: curCal,
        protein: curP,
        fats: curF,
        carbs: curC,
        fiber: curFiber,
        items: currentItems,
        cleanedDescription: _analysisResult?.cleanedDescription,
        rawResponse: _analysisResult?.rawResponse,
      );
      _isAddingIngredient = false;
      _addNameController.clear();
      _addWeightController.text = '100';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Added "${newItem.name}" (+${itemCal.round()} kcal)'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeIngredient(int index) {
    if (_analysisResult == null) return;
    final currentItems = List<FoodAnalysisItem>.from(_analysisResult!.items);
    if (index >= 0 && index < currentItems.length) {
      final removed = currentItems.removeAt(index);
      final itemCal = removed.calories ?? 0.0;
      final itemP = removed.protein ?? 0.0;
      final itemF = removed.fats ?? 0.0;
      final itemC = removed.carbs ?? 0.0;
      final itemFiber = 0.0;

      final curCal = ((double.tryParse(_caloriesController.text.trim()) ?? _analysisResult!.calories) - itemCal).clamp(0.0, double.infinity);
      final curP = ((double.tryParse(_proteinController.text.trim()) ?? _analysisResult!.protein) - itemP).clamp(0.0, double.infinity);
      final curF = ((double.tryParse(_fatsController.text.trim()) ?? _analysisResult!.fats) - itemF).clamp(0.0, double.infinity);
      final curC = ((double.tryParse(_carbsController.text.trim()) ?? _analysisResult!.carbs) - itemC).clamp(0.0, double.infinity);
      final curFiber = ((double.tryParse(_fiberController.text.trim()) ?? _analysisResult!.fiber) - itemFiber).clamp(0.0, double.infinity);

      setState(() {
        _caloriesController.text = curCal.toStringAsFixed(0);
        _proteinController.text = curP.toStringAsFixed(1);
        _fatsController.text = curF.toStringAsFixed(1);
        _carbsController.text = curC.toStringAsFixed(1);
        _fiberController.text = curFiber.toStringAsFixed(1);

        _analysisResult = FoodAnalysisResult(
          mealName: _mealNameController.text.trim().isNotEmpty
              ? _mealNameController.text.trim()
              : _analysisResult!.mealName,
          calories: curCal,
          protein: curP,
          fats: curF,
          carbs: curC,
          fiber: curFiber,
          items: currentItems,
          cleanedDescription: _analysisResult?.cleanedDescription,
          rawResponse: _analysisResult?.rawResponse,
        );
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 3 images per meal.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    try {
      if (source == ImageSource.gallery) {
        final List<XFile> picked = await _picker.pickMultiImage(
          limit: 3 - _selectedImages.length,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 70,
        );
        if (picked.isNotEmpty) {
          setState(() {
            for (final img in picked) {
              if (_selectedImages.length < 3) {
                _selectedImages.add(img);
              }
            }
          });
        }
      } else {
        final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 70,
        );
        if (photo != null) {
          setState(() {
            _selectedImages.add(photo);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture image: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _runAnalysis() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or capture at least one image.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final result = await FoodAnalysisService().analyzeFoodImages(
        images: _selectedImages,
        userNote: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      );

      if (!mounted) return;

      setState(() {
        _analysisResult = result;
        _mealNameController.text = result.mealName;
        _caloriesController.text = result.calories.toStringAsFixed(0);
        _proteinController.text = result.protein.toStringAsFixed(1);
        _fatsController.text = result.fats.toStringAsFixed(1);
        _carbsController.text = result.carbs.toStringAsFixed(1);
        _fiberController.text = result.fiber.toStringAsFixed(1);
        _isAnalyzing = false;
      });
    } catch (e, stack) {
      debugPrint('[FoodLoggingDialog AI Error] Full exception: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText(
            'AI Analysis failed: $e',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _runAnalysis,
          ),
        ),
      );
    }
  }

  void _saveLoggedMeal() {
    final mealName = _mealNameController.text.trim().isNotEmpty
        ? _mealNameController.text.trim()
        : (_analysisResult?.mealName ?? 'Logged Meal');
    final calories = double.tryParse(_caloriesController.text.trim()) ?? _analysisResult?.calories ?? 0.0;
    final protein = double.tryParse(_proteinController.text.trim()) ?? _analysisResult?.protein ?? 0.0;
    final fats = double.tryParse(_fatsController.text.trim()) ?? _analysisResult?.fats ?? 0.0;
    final carbs = double.tryParse(_carbsController.text.trim()) ?? _analysisResult?.carbs ?? 0.0;
    final fiber = double.tryParse(_fiberController.text.trim()) ?? _analysisResult?.fiber ?? 0.0;

    final imageToUpload = _selectedImages.isNotEmpty ? _selectedImages.first : null;
    final bloc = context.read<DietBloc>();

    bloc.add(
      LogActualMeal(
        date: widget.date,
        slotId: widget.slotId,
        actualMealName: mealName,
        calories: calories,
        protein: protein,
        fats: fats,
        carbs: carbs,
        fiber: fiber,
        userNote: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        aiBreakdown: _analysisResult?.items.map((i) => i.toMap()).toList(),
        completedAt: DateTime.now(),
      ),
    );

    if (imageToUpload != null) {
      MealPhotoService.uploadMealPhoto(
        image: imageToUpload,
        slotId: widget.slotId,
      ).then((uploadedUrl) {
        if (uploadedUrl != null) {
          bloc.add(
            UpdateSlotPhoto(
              date: widget.date,
              slotId: widget.slotId,
              photoUrl: uploadedUrl,
            ),
          );
        }
      }).catchError((e) {
        debugPrint('[FoodLoggingDialog] Photo upload background error: $e');
      });
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ "$mealName" logged successfully!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 460 ? 420.0 : (screenWidth * 0.92);

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _analysisResult == null ? 'Log Food (AI)' : 'Confirm Nutrition',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.slotName,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
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

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isAnalyzing)
                    _buildAnalyzingState()
                  else if (_analysisResult == null)
                    _buildImageInputStep()
                  else
                    _buildReviewStep(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppTheme.accent,
              strokeWidth: 3.5,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Analyzing Food with AI...',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Identifying ingredients, estimating portions, and calculating macros.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image preview / upload container
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _selectedImages.length + (_selectedImages.length < 3 ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index < _selectedImages.length) {
                  final file = _selectedImages[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(file.path, width: 100, height: 100, fit: BoxFit.cover)
                            : Image.file(File(file.path), width: 100, height: 100, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return _buildAddMoreButton();
                }
              },
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                const Icon(Icons.add_a_photo_outlined, size: 40, color: AppTheme.accent),
                const SizedBox(height: 12),
                const Text(
                  'Add 1 to 3 photos of your meal',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Photos help AI detect items and accurately estimate weight and macros.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Optional User Note TextField
        TextField(
          controller: _noteController,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Notes or hidden ingredients (optional)',
            hintText: 'e.g., 1 tbsp olive oil, extra cheese, dressing on the side',
            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF1E293B),
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
        const SizedBox(height: 20),

        // Action Buttons
        ElevatedButton.icon(
          onPressed: _selectedImages.isEmpty ? null : _runAnalysis,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text(
            'Analyze Food (AI)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.background,
            disabledBackgroundColor: const Color(0xFF334155),
            disabledForegroundColor: const Color(0xFF64748B),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddMoreButton() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.accent),
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
          const Text(
            'Add more',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Meal Name TextField
        TextField(
          controller: _mealNameController,
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Meal Name',
            labelStyle: const TextStyle(color: AppTheme.accent),
            filled: true,
            fillColor: const Color(0xFF1E293B),
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

        // Macros Editable Grid
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, size: 14, color: AppTheme.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    'Nutritional Estimation (Tap to edit)',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMacroField('Calories (kcal)', _caloriesController, const Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroField('Protein (g)', _proteinController, const Color(0xFFEF4444)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMacroField('Fats (g)', _fatsController, const Color(0xFFEAB308)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroField('Carbs (g)', _carbsController, const Color(0xFF3B82F6)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroField('Fiber (g)', _fiberController, const Color(0xFF10B981)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Recognized Ingredients / Items Breakdown & Add Ingredient
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detected Food Items',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_analysisResult?.items.length ?? 0} items',
                    style: const TextStyle(color: AppTheme.accent, fontSize: 12),
                  ),
                ],
              ),
              if (_analysisResult != null && _analysisResult!.items.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._analysisResult!.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.weight != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.weight!,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ),
                            if (item.calories != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${item.calories!.toStringAsFixed(0)} kcal',
                                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
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
                                Icon(Icons.add_circle_outline, size: 15, color: AppTheme.accent),
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
                                labelText: 'Ingredient',
                                hintText: 'e.g., Canned Tuna',
                                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
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
                                fillColor: const Color(0xFF1E293B),
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
        const SizedBox(height: 20),

        // Bottom Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _analysisResult = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Re-take'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _saveLoggedMeal,
                icon: const Icon(Icons.check, size: 18),
                label: const Text(
                  'Confirm & Save',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroField(String label, TextEditingController controller, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              borderSide: BorderSide(color: color),
            ),
          ),
        ),
      ],
    );
  }
}
