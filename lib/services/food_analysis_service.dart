import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FoodAnalysisItem {
  final String name;
  final String? weight;
  final double? calories;
  final double? protein;
  final double? fats;
  final double? carbs;

  FoodAnalysisItem({
    required this.name,
    this.weight,
    this.calories,
    this.protein,
    this.fats,
    this.carbs,
  });

  factory FoodAnalysisItem.fromMap(Map<String, dynamic> map) {
    return FoodAnalysisItem(
      name: map['name']?.toString() ?? map['item']?.toString() ?? 'Item',
      weight: map['weight']?.toString() ??
          (map['weight_g'] != null ? '${map['weight_g']}g' : null) ??
          map['portion']?.toString(),
      calories: (map['calories'] as num?)?.toDouble(),
      protein: (map['protein'] as num?)?.toDouble(),
      fats: (map['fats'] as num?)?.toDouble(),
      carbs: (map['carbs'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (weight != null) 'weight': weight,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (fats != null) 'fats': fats,
      if (carbs != null) 'carbs': carbs,
    };
  }
}

class FoodAnalysisResult {
  final String mealName;
  final double calories;
  final double protein;
  final double fats;
  final double carbs;
  final double fiber;
  final List<FoodAnalysisItem> items;
  final dynamic rawResponse;

  FoodAnalysisResult({
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.fats,
    required this.carbs,
    required this.fiber,
    this.items = const [],
    this.rawResponse,
  });

  FoodAnalysisResult copyWith({
    String? mealName,
    double? calories,
    double? protein,
    double? fats,
    double? carbs,
    double? fiber,
    List<FoodAnalysisItem>? items,
    dynamic rawResponse,
  }) {
    return FoodAnalysisResult(
      mealName: mealName ?? this.mealName,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      fats: fats ?? this.fats,
      carbs: carbs ?? this.carbs,
      fiber: fiber ?? this.fiber,
      items: items ?? this.items,
      rawResponse: rawResponse ?? this.rawResponse,
    );
  }

  factory FoodAnalysisResult.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map((item) => FoodAnalysisItem.fromMap(item))
        .toList();

    return FoodAnalysisResult(
      mealName: map['meal_name']?.toString() ?? map['name']?.toString() ?? 'Analyzed Meal',
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      fats: (map['fats'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0.0,
      items: items,
      rawResponse: map,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'meal_name': mealName,
      'calories': calories,
      'protein': protein,
      'fats': fats,
      'carbs': carbs,
      'fiber': fiber,
      'items': items.map((i) => i.toMap()).toList(),
    };
  }
}

class FoodAnalysisService {
  static final FoodAnalysisService _instance = FoodAnalysisService._internal();
  factory FoodAnalysisService() => _instance;
  FoodAnalysisService._internal();

  Future<FoodAnalysisResult> analyzeFoodImages({
    required List<XFile> images,
    String? userNote,
  }) async {
    if (images.isEmpty) {
      throw Exception('Please provide at least one food image for analysis.');
    }

    final List<String> base64Images = [];

    for (final image in images) {
      Uint8List? compressedBytes;
      try {
        if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
          compressedBytes = await FlutterImageCompress.compressWithFile(
            image.path,
            minWidth: 1024,
            minHeight: 1024,
            quality: 65,
            format: CompressFormat.jpeg,
          );
        }
      } catch (e) {
        debugPrint('Image compression error, falling back to direct bytes: $e');
      }

      compressedBytes ??= await image.readAsBytes();

      final kbSize = (compressedBytes.lengthInBytes / 1024).toStringAsFixed(1);
      debugPrint('Compressed food image [${image.name}]: $kbSize KB (${compressedBytes.lengthInBytes} bytes)');

      final base64String = base64Encode(compressedBytes);
      base64Images.add(base64String);
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'analyze-food',
        body: {
          'images': base64Images,
          'user_note': userNote ?? '',
        },
      );

      final dynamic responseData = response.data;
      Map<String, dynamic> jsonMap;
      if (responseData is Map<String, dynamic>) {
        jsonMap = responseData;
      } else if (responseData is String) {
        jsonMap = jsonDecode(responseData) as Map<String, dynamic>;
      } else {
        throw Exception('Unexpected response format from analyze-food Edge Function.');
      }

      return FoodAnalysisResult.fromMap(jsonMap);
    } catch (e) {
      debugPrint('Error calling analyze-food edge function: $e');
      rethrow;
    }
  }
}
