import 'package:uuid/uuid.dart';

class Meal {
  final String id;
  final String name;
  final String category; // 'Breakfast', 'Lunch', 'Dinner', 'Snack'
  final List<String> ingredients;

  Meal({
    String? id,
    required this.name,
    required this.category,
    required this.ingredients,
  }) : id = id ?? const Uuid().v4();

  Meal copyWith({
    String? id,
    String? name,
    String? category,
    List<String>? ingredients,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      ingredients: ingredients ?? this.ingredients,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'ingredients': ingredients,
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'Breakfast',
      ingredients: List<String>.from(map['ingredients'] ?? const []),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Meal.fromJson(Map<String, dynamic> json) => Meal.fromMap(json);
}
