class HabitGoal {
  int? id;
  String name;
  String? description;
  String icon;
  String color;
  String frequency;
  String? targetDays;
  String startDate;
  String? endDate;
  int isActive;
  String createdAt;
  String updatedAt;

  HabitGoal({
    this.id,
    required this.name,
    this.description,
    required this.icon,
    required this.color,
    required this.frequency,
    this.targetDays,
    required this.startDate,
    this.endDate,
    this.isActive = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'frequency': frequency,
      'target_days': targetDays,
      'start_date': startDate,
      'end_date': endDate,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory HabitGoal.fromMap(Map<String, dynamic> map) {
    return HabitGoal(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      icon: map['icon'],
      color: map['color'],
      frequency: map['frequency'],
      targetDays: map['target_days'],
      startDate: map['start_date'],
      endDate: map['end_date'],
      isActive: map['is_active'] ?? 1,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
