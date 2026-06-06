class ScheduleCategory {
  int? id;
  String name;
  String color;
  String icon;

  ScheduleCategory({
    this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'icon': icon,
    };
  }

  factory ScheduleCategory.fromMap(Map<String, dynamic> map) {
    return ScheduleCategory(
      id: map['id'],
      name: map['name'],
      color: map['color'],
      icon: map['icon'],
    );
  }
}
