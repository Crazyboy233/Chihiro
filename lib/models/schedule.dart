class Schedule {
  int? id;
  String title;
  String? description;
  String startTime;
  String? endTime;
  String? reminderTime;
  int? categoryId;
  int isAllDay;
  String? calendarEventId;
  String createdAt;
  String updatedAt;

  Schedule({
    this.id,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    this.reminderTime,
    this.categoryId,
    this.isAllDay = 0,
    this.calendarEventId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_time': startTime,
      'end_time': endTime,
      'reminder_time': reminderTime,
      'category_id': categoryId,
      'is_all_day': isAllDay,
      'calendar_event_id': calendarEventId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      startTime: map['start_time'],
      endTime: map['end_time'],
      reminderTime: map['reminder_time'],
      categoryId: map['category_id'],
      isAllDay: map['is_all_day'] ?? 0,
      calendarEventId: map['calendar_event_id'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
