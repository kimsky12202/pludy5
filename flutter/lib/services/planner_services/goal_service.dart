// lib/services/planner_services/goal_service.dart
// 목표 저장 및 관리 서비스
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/planner_models/planner_models.dart';

class GoalService {
  static const String _goalKey = 'goals';

  /// 모든 목표 가져오기
  static Future<List<Goal>> getAllGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final goalsJson = prefs.getString(_goalKey);

    if (goalsJson == null) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(goalsJson);
      return jsonList.map((json) => Goal.fromJson(json)).toList()
        ..sort((a, b) => a.deadline.compareTo(b.deadline));
    } catch (e) {
      print('목표 로드 오류: $e');
      return [];
    }
  }

  /// 목표 저장
  static Future<void> saveGoal(Goal goal) async {
    final allGoals = await getAllGoals();

    // 기존 목표가 있으면 업데이트, 없으면 추가
    final index = allGoals.indexWhere((g) => g.id == goal.id);
    if (index >= 0) {
      allGoals[index] = goal;
    } else {
      allGoals.add(goal);
    }

    await _saveAllGoals(allGoals);
  }

  /// 목표 삭제
  static Future<void> deleteGoal(String goalId) async {
    final allGoals = await getAllGoals();
    allGoals.removeWhere((g) => g.id == goalId);
    await _saveAllGoals(allGoals);
  }

  /// 목표 완료 상태 토글
  static Future<void> toggleGoalCompletion(String goalId) async {
    final allGoals = await getAllGoals();
    final index = allGoals.indexWhere((g) => g.id == goalId);

    if (index >= 0) {
      allGoals[index] = allGoals[index].copyWith(
        isCompleted: !allGoals[index].isCompleted,
      );
      await _saveAllGoals(allGoals);
    }
  }

  /// 모든 목표 저장
  static Future<void> _saveAllGoals(List<Goal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = goals.map((g) => g.toJson()).toList();
    await prefs.setString(_goalKey, json.encode(jsonList));
  }
}

