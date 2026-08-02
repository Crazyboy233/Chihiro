/// 倒数日 / 纪念日模型
///
/// 日程回答"那天要干嘛"，倒数日回答"还有多久"。
/// - type = countdown（倒数）：目标日在未来，显示"还有 N 天"，当天高亮"就是今天"
/// - type = countup（正数）：起始日在过去，显示"已坚持 N 天"（起始日算第 1 天）
class CountdownDay {
  static const String typeCountdown = 'countdown';
  static const String typeCountup = 'countup';

  int? id;
  String title;
  String targetDate; // 格式 yyyy-MM-dd
  String type; // countdown | countup
  String? color;
  String? note;
  String createdAt;
  String updatedAt;

  CountdownDay({
    this.id,
    required this.title,
    required this.targetDate,
    this.type = typeCountdown,
    this.color,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 目标日相对今天的天数差：>0 未来，=0 今天，<0 已过
  int get daysDiff {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime.parse(targetDate);
    return DateTime(d.year, d.month, d.day).difference(today).inDays;
  }

  /// 是否就是今天（到期高亮）
  bool get isToday => daysDiff == 0;

  bool get isCountup => type == typeCountup;

  /// 正数模式：已坚持天数（起始日算第 1 天）
  int get elapsedDays {
    final n = -daysDiff + 1;
    return n < 1 ? 1 : n;
  }

  /// 倒数模式：剩余天数（只在未来时有意义）
  int get remainingDays => daysDiff > 0 ? daysDiff : 0;

  /// 倒数模式：已过去多少天（目标日已过时）
  int get passedDays => daysDiff < 0 ? -daysDiff : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target_date': targetDate,
      'type': type,
      'color': color,
      'note': note,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory CountdownDay.fromMap(Map<String, dynamic> map) {
    return CountdownDay(
      id: map['id'],
      title: map['title'],
      targetDate: map['target_date'],
      type: map['type'] ?? typeCountdown,
      color: map['color'],
      note: map['note'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
