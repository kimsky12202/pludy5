// lib/models/planner_models/goal.dart
// 목표 모델

/// 목표 모델
class Goal {
  final String id;
  final String title;
  final String? description;
  final DateTime deadline; // 목표 마감일시
  final bool isCompleted;
  final DateTime createdAt;

  Goal({
    required this.id,
    required this.title,
    this.description,
    required this.deadline,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // JSON에서 생성
  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      deadline: DateTime.parse(json['deadline'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  // 복사 생성자
  Goal copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? deadline,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // 마감일까지 남은 시간 계산
  Duration get timeRemaining {
    final now = DateTime.now();
    if (deadline.isBefore(now)) {
      return Duration.zero;
    }
    return deadline.difference(now);
  }

  // 마감일이 지났는지 확인
  bool get isOverdue => deadline.isBefore(DateTime.now()) && !isCompleted;
}

