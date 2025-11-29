// lib/services/planner_services/schedule_service.dart
// 일정 저장 및 관리 서비스
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/planner_models/planner_models.dart';

class ScheduleService {
  static const String _scheduleKey = 'schedules';

  /// 모든 일정 가져오기
  static Future<List<Schedule>> getAllSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final schedulesJson = prefs.getString(_scheduleKey);
    
    if (schedulesJson == null) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(schedulesJson);
      return jsonList.map((json) => Schedule.fromJson(json)).toList();
    } catch (e) {
      print('일정 로드 오류: $e');
      return [];
    }
  }

  /// 특정 날짜의 일정 가져오기
  static Future<List<Schedule>> getSchedulesForDate(DateTime date) async {
    final allSchedules = await getAllSchedules();
    return allSchedules.where((schedule) {
      return schedule.date.year == date.year &&
          schedule.date.month == date.month &&
          schedule.date.day == date.day;
    }).toList()
      ..sort((a, b) {
        // 시간순으로 정렬
        if (a.startTime != null && b.startTime != null) {
          final aMinutes = a.startTime!.hour * 60 + a.startTime!.minute;
          final bMinutes = b.startTime!.hour * 60 + b.startTime!.minute;
          return aMinutes.compareTo(bMinutes);
        }
        return 0;
      });
  }

  /// 일정 저장
  static Future<void> saveSchedule(Schedule schedule) async {
    final allSchedules = await getAllSchedules();
    
    // 기존 일정이 있으면 업데이트, 없으면 추가
    final index = allSchedules.indexWhere((s) => s.id == schedule.id);
    if (index >= 0) {
      allSchedules[index] = schedule;
    } else {
      allSchedules.add(schedule);
    }

    await _saveAllSchedules(allSchedules);
  }

  /// 일정 삭제
  static Future<void> deleteSchedule(String scheduleId) async {
    final allSchedules = await getAllSchedules();
    allSchedules.removeWhere((s) => s.id == scheduleId);
    await _saveAllSchedules(allSchedules);
  }

  /// 일정 완료 상태 토글
  static Future<void> toggleScheduleCompletion(String scheduleId) async {
    final allSchedules = await getAllSchedules();
    final index = allSchedules.indexWhere((s) => s.id == scheduleId);
    
    if (index >= 0) {
      allSchedules[index] = allSchedules[index].copyWith(
        isCompleted: !allSchedules[index].isCompleted,
      );
      await _saveAllSchedules(allSchedules);
    }
  }

  /// 모든 일정 저장
  static Future<void> _saveAllSchedules(List<Schedule> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = schedules.map((s) => s.toJson()).toList();
    await prefs.setString(_scheduleKey, json.encode(jsonList));
  }
}

