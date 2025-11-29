// lib/services/planner_services/goal_service.dart
// 목표 저장 및 관리 서비스 (API 연동)
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../models/planner_models/planner_models.dart';
import '../auth.dart';

class GoalService {
  static final String baseUrl = AppConfig.baseUrl;

  /// 모든 목표 가져오기
  static Future<List<Goal>> getAllGoals() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/planner/goals'), headers: headers)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Goal.fromJson(json)).toList();
      } else {
        print('목표 로드 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('목표 로드 오류: $e');
      return [];
    }
  }

  /// 목표 저장 (생성 또는 업데이트)
  static Future<void> saveGoal(Goal goal) async {
    try {
      final headers = await AuthService.getAuthHeaders();

      // UUID 형식 확인 (8-4-4-4-12 형식)
      final uuidPattern = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          caseSensitive: false);
      final isServerGeneratedId = uuidPattern.hasMatch(goal.id);

      if (isServerGeneratedId) {
        // 서버에서 생성한 UUID → 업데이트
        final response = await http
            .put(
              Uri.parse('$baseUrl/api/planner/goals/${goal.id}'),
              headers: headers,
              body: json.encode(goal.toJson()),
            )
            .timeout(Duration(seconds: 10));

        if (response.statusCode != 200) {
          throw Exception('목표 업데이트 실패: ${response.statusCode}');
        }
      } else {
        // 로컬에서 생성한 타임스탬프 ID 또는 빈 ID → 새로 생성
        final goalData = goal.toJson();
        goalData.remove('id'); // 로컬 ID 제거 (서버가 UUID 생성)
        goalData.remove('createdAt'); // 서버가 생성

        final response = await http
            .post(
              Uri.parse('$baseUrl/api/planner/goals'),
              headers: headers,
              body: json.encode(goalData),
            )
            .timeout(Duration(seconds: 10));

        if (response.statusCode != 200) {
          throw Exception('목표 생성 실패: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('목표 저장 오류: $e');
      rethrow;
    }
  }

  /// 목표 삭제
  static Future<void> deleteGoal(String goalId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/planner/goals/$goalId'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('목표 삭제 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('목표 삭제 오류: $e');
      rethrow;
    }
  }

  /// 목표 완료 상태 토글
  static Future<void> toggleGoalCompletion(String goalId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .patch(
            Uri.parse('$baseUrl/api/planner/goals/$goalId/toggle'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('목표 상태 변경 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('목표 상태 변경 오류: $e');
      rethrow;
    }
  }
}

