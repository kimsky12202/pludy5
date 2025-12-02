// lib/providers/user_provider.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // HTTP 요청용
import '../services/auth_service.dart';
import '../services/quiz_api_service.dart';
import '../models/user_model.dart';
import '../models/quiz_models.dart';
import '../config/app_config.dart';

class UserProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final QuizApiService _quizApiService = QuizApiService();

  // 사용자 정보
  String? _userId;
  String? _username;
  String? _email;
  bool _isLoggedIn = false;

  // 퀴즈 데이터
  List<Quiz> _quizzes = [];
  bool _isLoadingQuizzes = false;
  String? _quizzesError;

  // 복습 데이터
  List<QuizQuestion> _reviewQuestions = [];
  bool _isLoadingReview = false;

  // Getters
  String? get userId => _userId;
  String? get username => _username;
  String? get email => _email;
  bool get isLoggedIn => _isLoggedIn;
  List<Quiz> get quizzes => _quizzes;
  bool get isLoadingQuizzes => _isLoadingQuizzes;
  String? get quizzesError => _quizzesError;
  List<QuizQuestion> get reviewQuestions => _reviewQuestions;
  bool get isLoadingReview => _isLoadingReview;

  // ========== 초기화 ==========

  Future<void> initialize() async {
    // 저장된 사용자 정보 불러오기
    final userInfo = await _authService.getUserInfo();
    if (userInfo != null) {
      _userId = userInfo['user_id'] as String;
      _username = userInfo['username'] as String;
      _email = userInfo['email'] as String;
      _isLoggedIn = true;
      notifyListeners();

      // 퀴즈 목록 로드
      await loadQuizzes();
      await loadReviewQuestions();
    }
  }

  // ========== 인증 ==========

  // [추가] 이미 받은 AuthToken으로 사용자 정보 설정
  Future<void> setUserFromAuthToken(AuthToken authToken) async {
    _userId = authToken.userId;
    _username = authToken.username;
    _email = authToken.email;
    _isLoggedIn = true;

    notifyListeners();

    // 퀴즈 목록 로드
    await loadQuizzes();
    await loadReviewQuestions();
  }

  Future<bool> login(String email, String password) async {
    try {
      final authToken = await _authService.login(
        email: email,
        password: password,
      );

      _userId = authToken.userId;
      _username = authToken.username;
      _email = authToken.email;
      _isLoggedIn = true;

      notifyListeners();

      // 퀴즈 목록 로드
      await loadQuizzes();
      await loadReviewQuestions();

      return true;
    } catch (e) {
      debugPrint('로그인 오류: $e');
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    try {
      final authToken = await _authService.register(
        username: username,
        email: email,
        password: password,
      );

      _userId = authToken.userId;
      _username = authToken.username;
      _email = authToken.email;
      _isLoggedIn = true;

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('회원가입 오류: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _userId = null;
    _username = null;
    _email = null;
    _isLoggedIn = false;
    _quizzes = [];
    _reviewQuestions = [];
    notifyListeners();
  }

  // [추가] 계정 삭제 (회원 탈퇴)
  Future<bool> deleteAccount() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        await logout(); // 성공하면 로그아웃 처리
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('계정 삭제 오류: $e');
      return false;
    }
  }

  // ========== 퀴즈 ==========

  Future<void> loadQuizzes() async {
    if (_userId == null) {
      debugPrint('❌ loadQuizzes: userId is null!');
      return;
    }

    debugPrint('📚 loadQuizzes: Loading quizzes for user $_userId');
    _isLoadingQuizzes = true;
    _quizzesError = null;
    notifyListeners();

    try {
      _quizzes = await _quizApiService.getUserQuizzes(_userId!);
      debugPrint('✅ loadQuizzes: Loaded ${_quizzes.length} quizzes');
      _quizzesError = null;
    } catch (e) {
      _quizzesError = '퀴즈 목록을 불러오는데 실패했습니다: $e';
      debugPrint('❌ loadQuizzes error: $_quizzesError');
    } finally {
      _isLoadingQuizzes = false;
      notifyListeners();
    }
  }

  Future<Quiz?> createQuiz(
    String quizName,
    List<QuizQuestion> questions,
  ) async {
    try {
      final newQuiz = await _quizApiService.createQuiz(
        quizName: quizName,
        questions: questions,
      );

      _quizzes.add(newQuiz);
      notifyListeners();

      return newQuiz;
    } catch (e) {
      debugPrint('퀴즈 생성 오류: $e');
      return null;
    }
  }

  Future<bool> deleteQuiz(String quizId) async {
    try {
      await _quizApiService.deleteQuiz(quizId);
      _quizzes.removeWhere((q) => q.id == quizId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('퀴즈 삭제 오류: $e');
      return false;
    }
  }

  // [추가] 퀴즈 질문 수정
  Future<bool> updateQuestion(
    String questionId,
    QuizQuestion updatedQuestion,
  ) async {
    try {
      final success = await _quizApiService.updateQuestion(
        questionId,
        updatedQuestion,
      );
      if (success) {
        await loadQuizzes(); // 목록 갱신
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('질문 수정 오류: $e');
      return false;
    }
  }

  // [추가] 퀴즈 제목 수정
  Future<bool> updateQuiz(String quizId, String quizName) async {
    try {
      final updatedQuiz = await _quizApiService.updateQuiz(quizId, quizName);

      // 로컬 목록에서 해당 퀴즈 업데이트
      final index = _quizzes.indexWhere((q) => q.id == quizId);
      if (index != -1) {
        _quizzes[index] = updatedQuiz;
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('퀴즈 제목 수정 오류: $e');
      return false;
    }
  }

  // ========== 복습 ==========

  Future<void> loadReviewQuestions() async {
    if (_userId == null) return;

    _isLoadingReview = true;
    notifyListeners();

    try {
      _reviewQuestions = await _quizApiService.getReviewQuestions(_userId!);
    } catch (e) {
      debugPrint('복습 질문 불러오기 오류: $e');
    } finally {
      _isLoadingReview = false;
      notifyListeners();
    }
  }

  Future<bool> submitQuizProgress({
    required String quizId,
    required List<Map<String, dynamic>> results,
  }) async {
    try {
      await _quizApiService.submitProgress(quizId: quizId, results: results);
      await loadReviewQuestions(); // 복습 목록 갱신
      return true;
    } catch (e) {
      debugPrint('진행 상황 제출 오류: $e');
      return false;
    }
  }
}
