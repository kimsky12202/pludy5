// lib/services/planner_services/schedule_service.dart
// 일정 저장 및 관리 서비스 (API 연동)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../models/planner_models/planner_models.dart';
import '../auth.dart';

class ScheduleService {
  static final String baseUrl = AppConfig.baseUrl;

  /// 모든 일정 가져오기
  static Future<List<Schedule>> getAllSchedules() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/planner/schedules'), headers: headers)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Schedule.fromJson(json)).toList();
      } else {
        print('일정 로드 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('일정 로드 오류: $e');
      return [];
    }
  }

  /// 특정 날짜의 일정 가져오기
  static Future<List<Schedule>> getSchedulesForDate(DateTime date) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/planner/schedules?date=$dateStr'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Schedule.fromJson(json)).toList();
      } else {
        print('일정 로드 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('일정 로드 오류: $e');
      return [];
    }
  }

  /// 일정 저장 (생성 또는 업데이트)
  static Future<void> saveSchedule(Schedule schedule) async {
    try {
      final headers = await AuthService.getAuthHeaders();

      final isUpdate = schedule.id.isNotEmpty;

      if (isUpdate) {
        // 업데이트
        final response = await http
            .put(
              Uri.parse('$baseUrl/api/planner/schedules/${schedule.id}'),
              headers: headers,
              body: json.encode(schedule.toJson()),
            )
            .timeout(Duration(seconds: 10));

        if (response.statusCode != 200) {
          throw Exception('일정 업데이트 실패: ${response.statusCode}');
        }
      } else {
        // 생성
        final response = await http
            .post(
              Uri.parse('$baseUrl/api/planner/schedules'),
              headers: headers,
              body: json.encode(schedule.toJson()),
            )
            .timeout(Duration(seconds: 10));

        if (response.statusCode != 200) {
          throw Exception('일정 생성 실패: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('일정 저장 오류: $e');
      rethrow;
    }
  }

  /// 일정 삭제
  static Future<void> deleteSchedule(String scheduleId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/planner/schedules/$scheduleId'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('일정 삭제 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('일정 삭제 오류: $e');
      rethrow;
    }
  }

  /// 일정 완료 상태 토글
  static Future<void> toggleScheduleCompletion(String scheduleId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .patch(
            Uri.parse('$baseUrl/api/planner/schedules/$scheduleId/toggle'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('일정 상태 변경 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('일정 상태 변경 오류: $e');
      rethrow;
    }
  }
}

