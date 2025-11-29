// lib/services/quiz_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/quiz_models.dart';
import 'auth_service.dart';

class QuizApiService {
  static const String baseUrl = '${AppConfig.baseUrl}/api';
  final AuthService _authService = AuthService();

  // 헤더 생성
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 사용자의 퀴즈 목록 조회
  Future<List<Quiz>> getUserQuizzes(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/quizzes'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Quiz.fromJson(json)).toList();
      } else {
        throw Exception('퀴즈 목록을 불러올 수 없습니다');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // 퀴즈 생성
  Future<Quiz> createQuiz({
    required String quizName,
    required List<QuizQuestion> questions,
  }) async {
    try {
      final questionsJson = questions.map((q) => q.toJson()).toList();

      final response = await http.post(
        Uri.parse('$baseUrl/quizzes'),
        headers: await _getHeaders(),
        body: jsonEncode({'quiz_name': quizName, 'questions': questionsJson}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Quiz.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '퀴즈 생성 실패');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // 퀴즈 상세 조회
  Future<Quiz> getQuizDetail(int quizId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/quizzes/$quizId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Quiz.fromJson(data);
      } else {
        throw Exception('퀴즈를 불러올 수 없습니다');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // 퀴즈 삭제
  Future<void> deleteQuiz(int quizId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/quizzes/$quizId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('퀴즈 삭제 실패');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // 퀴즈 진행 상황 제출
  Future<void> submitProgress({
    required int quizId,
    required List<Map<String, dynamic>> results,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/progress'),
        headers: await _getHeaders(),
        body: jsonEncode({'results': results}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('진행 상황 제출 실패');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // 복습이 필요한 질문 조회
  Future<List<QuizQuestion>> getReviewQuestions(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/progress?review_due=true'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => QuizQuestion.fromJson(json)).toList();
      } else {
        throw Exception('복습 질문을 불러올 수 없습니다');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // 사용자 진행 상황 조회
  Future<List<UserProgress>> getUserProgress(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/progress'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => UserProgress.fromJson(json)).toList();
      } else {
        throw Exception('진행 상황을 불러올 수 없습니다');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // [추가됨] 퀴즈 질문 수정하기
  Future<bool> updateQuestion(int questionId, QuizQuestion question) async {
    try {
      final url = Uri.parse('$baseUrl/questions/$questionId');
      final headers = await _getHeaders();

      final Map<String, dynamic> body = {
        'question_text': question.questionText,
        'correct_answer': question.correctAnswer,
        'answers':
            question.answers
                .map(
                  (a) => {
                    'answer_text': a.answerText,
                    'is_correct': a.isCorrect,
                    'answer_order': a.answerOrder,
                  },
                )
                .toList(),
      };

      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('질문 수정 실패: ${response.body}');
        return false;
      }
    } catch (e) {
      print('질문 수정 오류: $e');
      return false;
    }
  }
}
