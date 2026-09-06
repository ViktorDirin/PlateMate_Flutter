import 'dart:convert';
import 'dart:io';
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
      name: map['name']?.toString() ??
          map['item']?.toString() ??
          map['ingredient']?.toString() ??
          'Item',
      weight: map['weight']?.toString() ??
          (map['weight_g'] != null ? '${map['weight_g']}g' : null) ??
          map['portion']?.toString(),
      calories: (map['calories'] as num?)?.toDouble() ??
          (map['calories_kcal'] as num?)?.toDouble() ??
          (map['total_calories'] as num?)?.toDouble(),
      protein: (map['protein'] as num?)?.toDouble() ??
          (map['protein_g'] as num?)?.toDouble() ??
          (map['total_protein'] as num?)?.toDouble() ??
          (map['total_protein_g'] as num?)?.toDouble(),
      fats: (map['fats'] as num?)?.toDouble() ??
          (map['fats_g'] as num?)?.toDouble() ??
          (map['total_fats'] as num?)?.toDouble() ??
          (map['total_fats_g'] as num?)?.toDouble(),
      carbs: (map['carbs'] as num?)?.toDouble() ??
          (map['carbs_g'] as num?)?.toDouble() ??
          (map['total_carbs'] as num?)?.toDouble() ??
          (map['total_carbs_g'] as num?)?.toDouble(),
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
  final String? cleanedDescription;
  final dynamic rawResponse;

  FoodAnalysisResult({
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.fats,
    required this.carbs,
    required this.fiber,
    this.items = const [],
    this.cleanedDescription,
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
    String? cleanedDescription,
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
      cleanedDescription: cleanedDescription ?? this.cleanedDescription,
      rawResponse: rawResponse ?? this.rawResponse,
    );
  }

  factory FoodAnalysisResult.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .whereType<Map>()
        .map((item) => FoodAnalysisItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    final cleanedDesc = map['cleaned_description']?.toString() ??
        map['description']?.toString() ??
        (items.isNotEmpty
            ? items.map((i) => i.weight != null ? '${i.name} (${i.weight})' : i.name).join(', ')
            : null);

    return FoodAnalysisResult(
      mealName: map['meal_name']?.toString() ??
          map['name']?.toString() ??
          map['dish_name']?.toString() ??
          'Analyzed Meal',
      calories: (map['calories'] as num?)?.toDouble() ??
          (map['total_calories'] as num?)?.toDouble() ??
          0.0,
      protein: (map['protein'] as num?)?.toDouble() ??
          (map['protein_g'] as num?)?.toDouble() ??
          (map['total_protein'] as num?)?.toDouble() ??
          (map['total_protein_g'] as num?)?.toDouble() ??
          0.0,
      fats: (map['fats'] as num?)?.toDouble() ??
          (map['fats_g'] as num?)?.toDouble() ??
          (map['total_fats'] as num?)?.toDouble() ??
          (map['total_fats_g'] as num?)?.toDouble() ??
          0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ??
          (map['carbs_g'] as num?)?.toDouble() ??
          (map['total_carbs'] as num?)?.toDouble() ??
          (map['total_carbs_g'] as num?)?.toDouble() ??
          0.0,
      fiber: (map['fiber'] as num?)?.toDouble() ??
          (map['fiber_g'] as num?)?.toDouble() ??
          (map['total_fiber'] as num?)?.toDouble() ??
          (map['total_fiber_g'] as num?)?.toDouble() ??
          0.0,
      items: items,
      cleanedDescription: cleanedDesc,
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
      if (cleanedDescription != null) 'cleaned_description': cleanedDescription,
    };
  }
}

class FoodAnalysisService {
  static final FoodAnalysisService _instance = FoodAnalysisService._internal();
  factory FoodAnalysisService() => _instance;
  FoodAnalysisService._internal();

  static const String _cloudflareAccountId = String.fromEnvironment(
    'CLOUDFLARE_ACCOUNT_ID',
    defaultValue: 'cda94e1ccca49901c800971e405d2166',
  );
  static const String _cloudflareApiToken = String.fromEnvironment(
    'CLOUDFLARE_API_TOKEN',
    defaultValue: '',
  );
  static const String _cfVisionModel = '@cf/meta/llama-3.2-11b-vision-instruct';

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
      } else if (responseData is Map) {
        jsonMap = Map<String, dynamic>.from(responseData);
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

  Future<FoodAnalysisResult> estimateNutritionalValues({
    required String mealName,
    List<String> ingredients = const [],
    String? userNote,
  }) async {
    // 1. First attempt: Call Supabase analyze-food Edge Function
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'analyze-food',
        body: {
          'meal_name': mealName,
          'ingredients': ingredients,
          'text_prompt': ingredients.isNotEmpty
              ? '$mealName with ${ingredients.join(', ')}'
              : mealName,
          'user_note': userNote ?? '',
          'is_text_only': true,
        },
      );

      final dynamic responseData = response.data;
      if (responseData != null) {
        Map<String, dynamic> jsonMap;
        if (responseData is Map<String, dynamic>) {
          jsonMap = responseData;
        } else if (responseData is Map) {
          jsonMap = Map<String, dynamic>.from(responseData);
        } else if (responseData is String) {
          jsonMap = jsonDecode(responseData) as Map<String, dynamic>;
        } else {
          jsonMap = {};
        }

        if (jsonMap.containsKey('calories') ||
            jsonMap.containsKey('total_calories') ||
            jsonMap.containsKey('items')) {
          return FoodAnalysisResult.fromMap(jsonMap);
        }
      }
    } catch (e) {
      debugPrint('analyze-food Edge Function invocation failed ($e). Attempting direct Cloudflare AI...');
    }

    // 2. Second attempt: Direct Cloudflare Workers AI fallback with multilingual support
    try {
      return await _estimateWithCloudflareWorkersAi(
        mealName: mealName,
        ingredients: ingredients,
        userNote: userNote,
      );
    } catch (e) {
      debugPrint('Direct Cloudflare AI fallback failed ($e). Using local heuristic parser...');
    }

    // 3. Third attempt (MANDATORY & BULLETPROOF): Local Dart Heuristic Parser
    return LocalFoodParser.parse(
      mealName: mealName,
      ingredients: ingredients,
      userNote: userNote,
    );
  }

  Future<FoodAnalysisResult> _estimateWithCloudflareWorkersAi({
    required String mealName,
    List<String> ingredients = const [],
    String? userNote,
  }) async {
    final ingredientsText = ingredients.isNotEmpty ? ingredients.join(', ') : 'Standard serving';
    final noteText = (userNote != null && userNote.trim().isNotEmpty) ? ' Note: $userNote' : '';

    final prompt = '''
You are a certified nutritionist expert.
Analyze the provided meal and ingredients to calculate precise nutritional information.
CRITICAL INSTRUCTIONS:
1. The user input may be in Russian, English, or mixed. Parse each ingredient, translate or keep name recognizable, estimate realistic gram weights if omitted based on standard single adult servings.
2. Return ONLY a valid JSON object without markdown formatting, backticks, or extra commentary:
{
  "dish_name": "$mealName",
  "total_calories": 500,
  "total_protein_g": 30.0,
  "total_fats_g": 15.0,
  "total_carbs_g": 60.0,
  "total_fiber_g": 5.0,
  "items": [
    {
      "name": "Ingredient 1",
      "weight_g": 100,
      "calories": 200,
      "protein_g": 15.0,
      "fats_g": 5.0,
      "carbs_g": 20.0,
      "fiber_g": 2.0
    }
  ]
}

Meal: $mealName
Ingredients: $ingredientsText$noteText
''';

    if (!kIsWeb) {
      final uri = Uri.parse(
        'https://api.cloudflare.com/client/v4/accounts/$_cloudflareAccountId/ai/run/$_cfVisionModel',
      );
      final client = HttpClient();
      try {
        final request = await client.postUrl(uri);
        request.headers.set('Authorization', 'Bearer $_cloudflareApiToken');
        request.headers.set('Content-Type', 'application/json');

        final body = jsonEncode({
          'prompt': prompt,
          'max_tokens': 1024,
        });
        request.add(utf8.encode(body));

        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          final rawResponse = data['result']?['response'] ??
              data['result']?['description'] ??
              responseBody;
          final cleanedJson = _cleanJsonString(rawResponse.toString());
          final parsedMap = jsonDecode(cleanedJson) as Map<String, dynamic>;
          return FoodAnalysisResult.fromMap(parsedMap);
        } else {
          throw Exception('Cloudflare API HTTP ${response.statusCode}: $responseBody');
        }
      } finally {
        client.close();
      }
    } else {
      throw Exception('Direct fallback not supported on web platform.');
    }
  }

  static String _cleanJsonString(String str) {
    var cleaned = str.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();
    final startIdx = cleaned.indexOf('{');
    final endIdx = cleaned.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      cleaned = cleaned.substring(startIdx, endIdx + 1);
    }
    return cleaned;
  }
}

class _FoodMatcher {
  final String id;
  final String canonicalName;
  final RegExp pattern;
  final double defaultGrams;
  final double c100;
  final double p100;
  final double f100;
  final double carb100;
  final double fiber100;

  _FoodMatcher({
    required this.id,
    required this.canonicalName,
    required this.pattern,
    required this.defaultGrams,
    required this.c100,
    required this.p100,
    required this.f100,
    required this.carb100,
    this.fiber100 = 0.0,
  });
}

class _FoodMatchSpan {
  final _FoodMatcher matcher;
  final int start;
  final int end;
  final String matchText;

  _FoodMatchSpan({
    required this.matcher,
    required this.start,
    required this.end,
    required this.matchText,
  });
}

/// Offline / Heuristic Nutrition Estimator supporting Russian & English natural speech-to-text inputs
class LocalFoodParser {
  static final RegExp _weightRegex = RegExp(
    r'(?:в\s*|наверное\s*|около\s*|примерно\s*)?(\d+(?:[.,]\d+)?)\s*(?:г|g|гр|грамм[а-я]*|grams?|ml|мл)(?=[^a-zA-Z0-9а-яёА-ЯЁ]|$)',
    caseSensitive: false,
  );
  static final RegExp _countRegex = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(?:шт|штук[а-я]*|piece[s]?|pc[s]?|банк[а-я]*|can[s]?|порци[а-я]*|serving[s]?|кусок|куск[а-я]*|slice[s]?)(?=[^a-zA-Z0-9а-яёА-ЯЁ]|$)',
    caseSensitive: false,
  );

  static RegExp _foodRegex(String inner) {
    return RegExp(
      r'(?<=^|[^a-zA-Z0-9а-яёА-ЯЁ])(?:' + inner + r')(?=[^a-zA-Z0-9а-яёА-ЯЁ]|$)',
      caseSensitive: false,
    );
  }

  static final List<_FoodMatcher> _matchers = [
    _FoodMatcher(
      id: 'tuna',
      canonicalName: 'Canned Tuna',
      pattern: _foodRegex(r'консерв[а-я]*\s+(?:банк[а-я]*\s+)?тунц[а-я]*|тунец|тунц[а-я]*|canned\s+tuna|tuna'),
      defaultGrams: 100,
      c100: 100,
      p100: 24.0,
      f100: 1.0,
      carb100: 0.0,
    ),
    _FoodMatcher(
      id: 'egg',
      canonicalName: 'Boiled Egg',
      pattern: _foodRegex(r'вар[её]н[а-я]*\s+яйц[а-я]*|boiled\s+egg[s]?|яйц[а-я]*|яиц[а-я]*|egg[s]?'),
      defaultGrams: 50,
      c100: 143,
      p100: 12.6,
      f100: 9.5,
      carb100: 0.7,
    ),
    _FoodMatcher(
      id: 'cucumber',
      canonicalName: 'Cucumber',
      pattern: _foodRegex(r'огур[ец|ц][а-я]*|cucumber[s]?'),
      defaultGrams: 100,
      c100: 15,
      p100: 0.8,
      f100: 0.1,
      carb100: 3.6,
      fiber100: 0.8,
    ),
    _FoodMatcher(
      id: 'tomato',
      canonicalName: 'Tomato',
      pattern: _foodRegex(r'cherry\s+tomato[es]?|черри|помидор[а-я]*|томат[а-я]*|tomato[es]?'),
      defaultGrams: 100,
      c100: 18,
      p100: 0.9,
      f100: 0.2,
      carb100: 3.9,
      fiber100: 1.2,
    ),
    _FoodMatcher(
      id: 'salad',
      canonicalName: 'Salad Greens',
      pattern: _foodRegex(r'салатн[а-я]*\s+лист[а-я]*|лист[а-я]*\s+салат[а-я]*|салат\s+айсберг|айсберг|зелен[а-я]*|шпинат[а-я]*|руккол[а-я]*|салат[а-я]*|lettuce|spinach|greens|salad\s+greens|salad'),
      defaultGrams: 80,
      c100: 15,
      p100: 1.2,
      f100: 0.2,
      carb100: 2.5,
      fiber100: 1.5,
    ),
    _FoodMatcher(
      id: 'chicken',
      canonicalName: 'Chicken Breast',
      pattern: _foodRegex(r'chicken\s+breast|курин[а-я]*\s+грудк[а-я]*|филе\s+куриц[а-я]*|филе\s+индейк[а-я]*|куриц[а-я]*|курин[а-я]*|грудк[а-я]*|филе|индейк[а-я]*|chicken|turkey|breast'),
      defaultGrams: 150,
      c100: 160,
      p100: 31.0,
      f100: 3.6,
      carb100: 0.0,
    ),
    _FoodMatcher(
      id: 'meat',
      canonicalName: 'Beef / Meat',
      pattern: _foodRegex(r'beef\s+steak|стейк|говядин[а-я]*|свинин[а-я]*|мяс[а-я]*|фарш[а-я]*|beef|pork|meat|steak'),
      defaultGrams: 150,
      c100: 220,
      p100: 25.0,
      f100: 13.0,
      carb100: 0.0,
    ),
    _FoodMatcher(
      id: 'fish',
      canonicalName: 'Salmon / Fish',
      pattern: _foodRegex(r'salmon\s+fillet|филе\s+лосос[а-я]*|лосос[а-я]*|семг[а-я]*|форел[а-я]*|рыб[а-я]*|треск[а-я]*|судак[а-я]*|salmon|fish|cod'),
      defaultGrams: 150,
      c100: 180,
      p100: 20.0,
      f100: 11.0,
      carb100: 0.0,
    ),
    _FoodMatcher(
      id: 'oats',
      canonicalName: 'Rolled Oats',
      pattern: _foodRegex(r'rolled\s+oats|овсян[а-я]*\s+хлопь[а-я]*|овсянк[а-я]*|геркулес[а-я]*|каш[а-я]*|oatmeal|oats|porridge'),
      defaultGrams: 60,
      c100: 360,
      p100: 12.0,
      f100: 6.0,
      carb100: 62.0,
      fiber100: 6.0,
    ),
    _FoodMatcher(
      id: 'milk',
      canonicalName: 'Milk',
      pattern: _foodRegex(r'almond\s+milk|миндальн[а-я]*\s+молок[а-я]*|молок[а-я]*|сливк[а-я]*|milk|cream'),
      defaultGrams: 180,
      c100: 48,
      p100: 3.2,
      f100: 2.0,
      carb100: 4.8,
    ),
    _FoodMatcher(
      id: 'rice',
      canonicalName: 'Rice',
      pattern: _foodRegex(r'white\s+rice|brown\s+rice|рис[а-я]*|rice'),
      defaultGrams: 150,
      c100: 130,
      p100: 2.7,
      f100: 0.3,
      carb100: 28.0,
    ),
    _FoodMatcher(
      id: 'pasta',
      canonicalName: 'Pasta',
      pattern: _foodRegex(r'egg\s+noodles|макарон[а-я]*|паст[а-я]*|спагетти|лапш[а-я]*|pasta|noodles|spaghetti'),
      defaultGrams: 160,
      c100: 150,
      p100: 5.5,
      f100: 1.0,
      carb100: 30.0,
    ),
    _FoodMatcher(
      id: 'potato',
      canonicalName: 'Potato',
      pattern: _foodRegex(r'картоф[а-я]*|картошк[а-я]*|пюр[е|я]|potato[es]?'),
      defaultGrams: 150,
      c100: 80,
      p100: 2.0,
      f100: 0.1,
      carb100: 18.0,
      fiber100: 1.8,
    ),
    _FoodMatcher(
      id: 'bread',
      canonicalName: 'Bread / Toast',
      pattern: _foodRegex(r'хлеб[а-я]*|тост[а-я]*|булочк[а-я]*|лаваш[а-я]*|bread|toast|pita'),
      defaultGrams: 40,
      c100: 240,
      p100: 8.5,
      f100: 2.5,
      carb100: 46.0,
      fiber100: 2.5,
    ),
    _FoodMatcher(
      id: 'cheese',
      canonicalName: 'Cheese',
      pattern: _foodRegex(r'сыр[а-я]*|пармезан[а-я]*|моцарелл[а-я]*|cheese'),
      defaultGrams: 30,
      c100: 350,
      p100: 24.0,
      f100: 28.0,
      carb100: 1.5,
    ),
    _FoodMatcher(
      id: 'cottage_cheese',
      canonicalName: 'Cottage Cheese',
      pattern: _foodRegex(r'творог[а-я]*|творож[а-я]*|cottage\s*cheese|ricotta'),
      defaultGrams: 150,
      c100: 100,
      p100: 16.0,
      f100: 2.0,
      carb100: 3.0,
    ),
    _FoodMatcher(
      id: 'yogurt',
      canonicalName: 'Yogurt',
      pattern: _foodRegex(r'йогурт[а-я]*|yogurt'),
      defaultGrams: 150,
      c100: 65,
      p100: 5.0,
      f100: 2.0,
      carb100: 6.0,
    ),
    _FoodMatcher(
      id: 'oil',
      canonicalName: 'Olive / Vegetable Oil',
      pattern: _foodRegex(r'olive\s+oil|растительн[а-я]*\s+масл[а-я]*|оливков[а-я]*\s+масл[а-я]*|масл[а-я]*|butter|oil'),
      defaultGrams: 10,
      c100: 880,
      p100: 0.0,
      f100: 99.0,
      carb100: 0.0,
    ),
    _FoodMatcher(
      id: 'apple',
      canonicalName: 'Apple',
      pattern: _foodRegex(r'яблок[а-я]*|apple[s]?'),
      defaultGrams: 150,
      c100: 52,
      p100: 0.3,
      f100: 0.2,
      carb100: 14.0,
      fiber100: 2.4,
    ),
    _FoodMatcher(
      id: 'banana',
      canonicalName: 'Banana',
      pattern: _foodRegex(r'банан[а-я]*|banana[s]?'),
      defaultGrams: 120,
      c100: 89,
      p100: 1.1,
      f100: 0.3,
      carb100: 23.0,
      fiber100: 2.6,
    ),
    _FoodMatcher(
      id: 'berries',
      canonicalName: 'Berries',
      pattern: _foodRegex(r'ягод[а-я]*|клубник[а-я]*|черник[а-я]*|малин[а-я]*|голубик[а-я]*|berr(?:y|ies)|blueberr(?:y|ies)|strawberr(?:y|ies)'),
      defaultGrams: 60,
      c100: 50,
      p100: 0.8,
      f100: 0.4,
      carb100: 11.0,
      fiber100: 2.5,
    ),
    _FoodMatcher(
      id: 'avocado',
      canonicalName: 'Avocado',
      pattern: _foodRegex(r'авокадо|avocado'),
      defaultGrams: 75,
      c100: 160,
      p100: 2.0,
      f100: 15.0,
      carb100: 8.5,
      fiber100: 6.7,
    ),
    _FoodMatcher(
      id: 'nuts',
      canonicalName: 'Nuts',
      pattern: _foodRegex(r'орех[а-я]*|миндал[а-я]*|арахис[а-я]*|фундук[а-я]*|грецк[а-я]*|nut[s]?|walnut[s]?|almond[s]?|peanut[s]?'),
      defaultGrams: 25,
      c100: 600,
      p100: 16.0,
      f100: 55.0,
      carb100: 14.0,
      fiber100: 4.0,
    ),
    _FoodMatcher(
      id: 'sweetener',
      canonicalName: 'Honey / Sweetener',
      pattern: _foodRegex(r'мед[а-я]*|мёд[а-я]*|сахар[а-я]*|сироп[а-я]*|honey|sugar|syrup'),
      defaultGrams: 15,
      c100: 300,
      p100: 0.3,
      f100: 0.0,
      carb100: 80.0,
    ),
    _FoodMatcher(
      id: 'soup',
      canonicalName: 'Soup',
      pattern: _foodRegex(r'суп[а-я]*|борщ[а-я]*|щи|бульон[а-я]*|soup|broth'),
      defaultGrams: 300,
      c100: 45,
      p100: 2.5,
      f100: 1.5,
      carb100: 5.5,
      fiber100: 1.5,
    ),
  ];

  static FoodAnalysisResult parse({
    required String mealName,
    List<String> ingredients = const [],
    String? userNote,
  }) {
    final nonBlankIngredients = ingredients.where((s) => s.trim().isNotEmpty).toList();
    final String targetText;
    if (nonBlankIngredients.isNotEmpty) {
      targetText = nonBlankIngredients.join(', ');
    } else if (userNote != null && userNote.trim().isNotEmpty) {
      targetText = userNote.trim();
    } else {
      targetText = mealName.trim();
    }

    final items = _extractAllFoodItems(targetText);

    if (items.isEmpty) {
      // Standard healthy single adult meal fallback
      const totalCalories = 360.0;
      const totalProtein = 26.0;
      const totalFats = 12.0;
      const totalCarbs = 38.0;
      const totalFiber = 4.0;
      final fallbackItem = FoodAnalysisItem(
        name: mealName.isNotEmpty ? mealName : 'Standard Meal Serving',
        weight: '1 serving',
        calories: totalCalories,
        protein: totalProtein,
        fats: totalFats,
        carbs: totalCarbs,
      );

      return FoodAnalysisResult(
        mealName: mealName.isNotEmpty ? mealName : 'Estimated Dish',
        calories: totalCalories,
        protein: totalProtein,
        fats: totalFats,
        carbs: totalCarbs,
        fiber: totalFiber,
        items: [fallbackItem],
        cleanedDescription: fallbackItem.name,
        rawResponse: {'source': 'local_heuristic_parser'},
      );
    }

    double totalCalories = 0;
    double totalProtein = 0;
    double totalFats = 0;
    double totalCarbs = 0;
    double totalFiber = 0;

    for (final item in items) {
      totalCalories += item.calories ?? 0;
      totalProtein += item.protein ?? 0;
      totalFats += item.fats ?? 0;
      totalCarbs += item.carbs ?? 0;
    }

    final cleanedDescription = items
        .map((i) => i.weight != null ? '${i.name} (${i.weight})' : i.name)
        .join(', ');

    return FoodAnalysisResult(
      mealName: mealName.isNotEmpty ? mealName : 'Estimated Dish',
      calories: totalCalories,
      protein: double.parse(totalProtein.toStringAsFixed(1)),
      fats: double.parse(totalFats.toStringAsFixed(1)),
      carbs: double.parse(totalCarbs.toStringAsFixed(1)),
      fiber: double.parse(totalFiber.toStringAsFixed(1)),
      items: items,
      cleanedDescription: cleanedDescription,
      rawResponse: {'source': 'local_heuristic_parser'},
    );
  }

  static List<FoodAnalysisItem> _extractAllFoodItems(String text) {
    if (text.trim().isEmpty) return [];

    final rawMatches = <_FoodMatchSpan>[];

    for (final matcher in _matchers) {
      for (final match in matcher.pattern.allMatches(text)) {
        rawMatches.add(_FoodMatchSpan(
          matcher: matcher,
          start: match.start,
          end: match.end,
          matchText: text.substring(match.start, match.end),
        ));
      }
    }

    if (rawMatches.isEmpty) {
      // Fallback: try comma/newline splitting
      final parts = text.split(RegExp(r'[,;\n\r\+]|\bи\b|\band\b', caseSensitive: false));
      final result = <FoodAnalysisItem>[];
      for (final p in parts) {
        final trimmed = p.trim();
        if (trimmed.isNotEmpty) {
          result.add(FoodAnalysisItem(
            name: trimmed,
            weight: '100g',
            calories: 120,
            protein: 5.0,
            fats: 3.0,
            carbs: 15.0,
          ));
        }
      }
      return result;
    }

    // Sort spans by occurrence in text (prefer longer matches for same start)
    rawMatches.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      if (cmp != 0) return cmp;
      return b.end.compareTo(a.end);
    });

    // Remove overlapping spans (keep the first or longer one)
    final nonOverlapping = <_FoodMatchSpan>[];
    int lastEnd = -1;
    for (final span in rawMatches) {
      if (span.start >= lastEnd) {
        nonOverlapping.add(span);
        lastEnd = span.end;
      }
    }

    final items = <FoodAnalysisItem>[];

    for (int i = 0; i < nonOverlapping.length; i++) {
      final currentSpan = nonOverlapping[i];
      final contextStart = (i == 0) ? 0 : nonOverlapping[i - 1].end;
      final contextEnd = (i == nonOverlapping.length - 1) ? text.length : nonOverlapping[i + 1].start;

      final beforeMatch = text.substring(contextStart, currentSpan.start);
      final afterMatch = text.substring(currentSpan.end, contextEnd);

      final item = _parseItemFromContext(currentSpan.matcher, beforeMatch, afterMatch);
      items.add(item);
    }

    return items;
  }

  static FoodAnalysisItem _parseItemFromContext(_FoodMatcher matcher, String before, String after) {
    final lowerBefore = before.toLowerCase();
    final lowerAfter = after.toLowerCase();
    double? grams;

    // 1. Search for explicit weight in afterMatch first, then beforeMatch
    final afterWeightMatch = _weightRegex.firstMatch(lowerAfter);
    if (afterWeightMatch != null) {
      grams = double.tryParse(afterWeightMatch.group(1)!.replaceAll(',', '.'));
    } else {
      final beforeWeightMatch = _weightRegex.firstMatch(lowerBefore);
      if (beforeWeightMatch != null) {
        grams = double.tryParse(beforeWeightMatch.group(1)!.replaceAll(',', '.'));
      }
    }

    // 2. Search for counts/portions
    double count = 1.0;
    if (grams == null) {
      final afterCountMatch = _countRegex.firstMatch(lowerAfter);
      final beforeCountMatch = _countRegex.firstMatch(lowerBefore);

      if (afterCountMatch != null) {
        count = double.tryParse(afterCountMatch.group(1)!.replaceAll(',', '.')) ?? 1.0;
      } else if (beforeCountMatch != null) {
        count = double.tryParse(beforeCountMatch.group(1)!.replaceAll(',', '.')) ?? 1.0;
      } else {
        final countFromBefore = _extractSpokenCount(lowerBefore);
        final countFromAfter = _extractSpokenCount(lowerAfter);
        count = (countFromBefore != 1.0) ? countFromBefore : countFromAfter;
      }
    }

    final finalGrams = grams ?? (matcher.defaultGrams * count);
    final multiplier = finalGrams / 100.0;

    final cal = (matcher.c100 * multiplier).roundToDouble();
    final p = double.parse((matcher.p100 * multiplier).toStringAsFixed(1));
    final f = double.parse((matcher.f100 * multiplier).toStringAsFixed(1));
    final c = double.parse((matcher.carb100 * multiplier).toStringAsFixed(1));

    return FoodAnalysisItem(
      name: matcher.canonicalName,
      weight: '${finalGrams.round()}g',
      calories: cal,
      protein: p,
      fats: f,
      carbs: c,
    );
  }

  static double _extractSpokenCount(String lower) {
    final cleaned = lower.contains('нет') ? lower.substring(lower.lastIndexOf('нет')) : lower;

    if (cleaned.contains('пять') || cleaned.contains(' 5 ')) return 5.0;
    if (cleaned.contains('четыре') || cleaned.contains(' 4 ')) return 4.0;
    if (cleaned.contains('три') || cleaned.contains(' 3 ')) return 3.0;
    if (cleaned.contains('два') || cleaned.contains('две') || cleaned.contains(' 2 ')) return 2.0;
    if (cleaned.contains('пол') || cleaned.contains('половин')) return 0.5;
    if (cleaned.contains('один') || cleaned.contains('одна') || cleaned.contains('одно') || cleaned.contains('одну') || cleaned.contains(' 1 ')) return 1.0;

    return 1.0;
  }
}
