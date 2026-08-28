class MealSlotConfig {
  final String id;
  final String name;
  final int orderIndex;
  final bool isEnabled;

  MealSlotConfig({
    required this.id,
    required this.name,
    required this.orderIndex,
    this.isEnabled = true,
  });

  MealSlotConfig copyWith({
    String? id,
    String? name,
    int? orderIndex,
    bool? isEnabled,
  }) {
    return MealSlotConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'orderIndex': orderIndex,
      'isEnabled': isEnabled,
    };
  }

  factory MealSlotConfig.fromMap(Map<String, dynamic> map) {
    return MealSlotConfig(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      orderIndex: map['orderIndex'] as int? ?? 0,
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory MealSlotConfig.fromJson(Map<String, dynamic> json) => MealSlotConfig.fromMap(json);
}
