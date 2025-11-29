import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/quiz_models.dart';
import 'auth_service.dart';

class QuizService {
  static const String baseUrl = '${AppConfig.baseUrl}/api';
  final AuthService _authService = AuthService();

  /// 사용자의 퀴즈 목록 조회
  Future<List<Quiz>> getUserQuizzes(int userId) async {
    try {
      final token = await _authService.getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/quizzes'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Quiz.fromJson(json)).toList();
      } else {
        throw Exception('퀴즈 목록 로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('퀴즈 목록 로드 오류: $e');
    }
  }

  /// 퀴즈 생성
  Future<Quiz> createQuiz({
    required String quizName,
    required List<QuizQuestion> questions,
  }) async {
    try {
      final token = await _authService.getToken();

      final response = await http.post(
        Uri.parse('$baseUrl/quizzes'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'quiz_name': quizName,
          'questions': questions.map((q) => q.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Quiz.fromJson(data);
      } else {
        throw Exception('퀴즈 생성 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('퀴즈 생성 오류: $e');
    }
  }

  /// 퀴즈 삭제
  Future<void> deleteQuiz(int quizId) async {
    try {
      final token = await _authService.getToken();

      final response = await http.delete(
        Uri.parse('$baseUrl/quizzes/$quizId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('퀴즈 삭제 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('퀴즈 삭제 오류: $e');
    }
  }

  /// 퀴즈 진행 결과 제출
  Future<void> submitProgress({
    required List<Map<String, dynamic>> results,
  }) async {
    try {
      final token = await _authService.getToken();

      final response = await http.post(
        Uri.parse('$baseUrl/progress'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'results': results}),
      );

      if (response.statusCode != 200) {
        throw Exception('진행 상황 저장 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('진행 상황 저장 오류: $e');
    }
  }

  /// 복습 필요한 문제 조회
  Future<List<dynamic>> getReviewDueProgress(int userId) async {
    try {
      final token = await _authService.getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/progress?review_due=true'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('복습 목록 로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('복습 목록 로드 오류: $e');
    }
  }
}
