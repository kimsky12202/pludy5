// lib/models/planner_models/schedule.dart
// 일정 모델
import 'package:flutter/material.dart';

/// 일정 모델
class Schedule {
  final String id;
  final DateTime date;
  final String title;
  final String? description;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool isCompleted;
  final Color? color; // 시간표에서 표시할 색상

  Schedule({
    required this.id,
    required this.date,
    required this.title,
    this.description,
    this.startTime,
    this.endTime,
    this.isCompleted = false,
    this.color,
  });

  // JSON으로 변환 (저장용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'description': description,
      'startTime': startTime != null
          ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'endTime': endTime != null
          ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'isCompleted': isCompleted,
      'color': color != null ? color!.value : null,
    };
  }

  // JSON에서 생성
  factory Schedule.fromJson(Map<String, dynamic> json) {
    final startTimeStr = json['startTime'] as String?;
    final endTimeStr = json['endTime'] as String?;

    TimeOfDay? startTime;
    TimeOfDay? endTime;

    if (startTimeStr != null) {
      final parts = startTimeStr.split(':');
      startTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    if (endTimeStr != null) {
      final parts = endTimeStr.split(':');
      endTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    Color? color;
    if (json['color'] != null) {
      color = Color(json['color'] as int);
    }

    return Schedule(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: startTime,
      endTime: endTime,
      isCompleted: json['isCompleted'] as bool? ?? false,
      color: color,
    );
  }

  // 복사 생성자 (수정용)
  Schedule copyWith({
    String? id,
    DateTime? date,
    String? title,
    String? description,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isCompleted,
    Color? color,
  }) {
    return Schedule(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isCompleted: isCompleted ?? this.isCompleted,
      color: color ?? this.color,
    );
  }
}

