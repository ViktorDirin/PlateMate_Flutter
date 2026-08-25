import 'package:uuid/uuid.dart';

class Ingredient {
  final String name;
  final double quantity;
  final String unit; // 'gr', 'pcs', 'ml'

  Ingredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  Ingredient copyWith({
    String? name,
    double? quantity,
    String? unit,
  }) {
    return Ingredient(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? 'gr',
    );
  }
}

class Meal {
  final String id;
  final String name;
  final String category; // 'Breakfast', 'Lunch', 'Dinner'
  final String time; // 'HH:MM'
  final String date; // 'YYYY-MM-DD'
  final int sortOrder;
  final List<Ingredient> ingredients;

  Meal({
    String? id,
    required this.name,
    required this.category,
    required this.time,
    required this.date,
    required this.sortOrder,
    required this.ingredients,
  }) : id = id ?? const Uuid().v4();

  Meal copyWith({
    String? id,
    String? name,
    String? category,
    String? time,
    String? date,
    int? sortOrder,
    List<Ingredient>? ingredients,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      time: time ?? this.time,
      date: date ?? this.date,
      sortOrder: sortOrder ?? this.sortOrder,
      ingredients: ingredients ?? this.ingredients,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'time': time,
      'date': date,
      'sort_order': sortOrder,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
    };
  }

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Breakfast',
      time: json['time'] as String? ?? '08:00',
      date: json['date'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DietPlan {
  final String id;
  final String name;
  final bool isDefault;
  final List<Meal> meals;
  final DateTime updatedAt;

  DietPlan({
    String? id,
    required this.name,
    this.isDefault = false,
    required this.meals,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        updatedAt = updatedAt ?? DateTime.now();

  DietPlan copyWith({
    String? id,
    String? name,
    bool? isDefault,
    List<Meal>? meals,
    DateTime? updatedAt,
  }) {
    return DietPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      meals: meals ?? this.meals,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_default': isDefault,
      'meals': meals.map((m) => m.toJson()).toList(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DietPlan.fromJson(Map<String, dynamic> json) {
    return DietPlan(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
      meals: (json['meals'] as List<dynamic>?)
              ?.map((m) => Meal.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}
