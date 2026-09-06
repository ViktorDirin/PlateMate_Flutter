import 'package:uuid/uuid.dart';

class Meal {
  final String id;
  final String name;
  final String category; // 'Breakfast', 'Lunch', 'Dinner', 'Snack'
  final List<String> ingredients;
  final double? calories;
  final double? protein;
  final double? fats;
  final double? carbs;
  final double? fiber;
  final dynamic aiBreakdown;
  final double defaultServings;

  Meal({
    String? id,
    required this.name,
    required this.category,
    required this.ingredients,
    this.calories,
    this.protein,
    this.fats,
    this.carbs,
    this.fiber,
    this.aiBreakdown,
    this.defaultServings = 1.0,
  }) : id = id ?? const Uuid().v4();

  Meal copyWith({
    String? id,
    String? name,
    String? category,
    List<String>? ingredients,
    double? calories,
    double? protein,
    double? fats,
    double? carbs,
    double? fiber,
    dynamic aiBreakdown,
    double? defaultServings,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      ingredients: ingredients ?? this.ingredients,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      fats: fats ?? this.fats,
      carbs: carbs ?? this.carbs,
      fiber: fiber ?? this.fiber,
      aiBreakdown: aiBreakdown ?? this.aiBreakdown,
      defaultServings: defaultServings ?? this.defaultServings,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'ingredients': ingredients,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (fats != null) 'fats': fats,
      if (carbs != null) 'carbs': carbs,
      if (fiber != null) 'fiber': fiber,
      if (aiBreakdown != null) 'ai_breakdown': aiBreakdown,
      'default_servings': defaultServings,
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      id: map['id'] as String? ?? const Uuid().v4(),
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'Breakfast',
      ingredients: List<String>.from(map['ingredients'] ?? const []),
      calories: (map['calories'] as num?)?.toDouble(),
      protein: (map['protein'] as num?)?.toDouble(),
      fats: (map['fats'] as num?)?.toDouble(),
      carbs: (map['carbs'] as num?)?.toDouble(),
      fiber: (map['fiber'] as num?)?.toDouble(),
      aiBreakdown: map['ai_breakdown'] ?? map['aiBreakdown'],
      defaultServings: (map['default_servings'] as num?)?.toDouble() ??
          (map['defaultServings'] as num?)?.toDouble() ??
          1.0,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Meal.fromJson(Map<String, dynamic> json) => Meal.fromMap(json);
}
