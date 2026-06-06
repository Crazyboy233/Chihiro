class HabitRecord {
  int? id;
  int goalId;
  String date;
  int isCompleted;
  String? note;
  String createdAt;

  HabitRecord({
    this.id,
    required this.goalId,
    required this.date,
    this.isCompleted = 0,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal_id': goalId,
      'date': date,
      'is_completed': isCompleted,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory HabitRecord.fromMap(Map<String, dynamic> map) {
    return HabitRecord(
      id: map['id'],
      goalId: map['goal_id'],
      date: map['date'],
      isCompleted: map['is_completed'] ?? 0,
      note: map['note'],
      createdAt: map['created_at'],
    );
  }
}
