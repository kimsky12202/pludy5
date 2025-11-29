// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';

class AuthService {
  static const String baseUrl = '${AppConfig.baseUrl}/api';

  // 토큰 저장
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // 토큰 가져오기
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // 토큰 삭제
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // 사용자 정보 저장
  Future<void> saveUserInfo(int userId, String username, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', userId);
    await prefs.setString('username', username);
    await prefs.setString('email', email);
  }

  // 사용자 정보 가져오기
  Future<Map<String, dynamic>?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final username = prefs.getString('username');
    final email = prefs.getString('email');

    if (userId == null || username == null || email == null) {
      return null;
    }

    return {'user_id': userId, 'username': username, 'email': email};
  }

  // 사용자 정보 삭제
  Future<void> clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('email');
  }

  // 헤더 생성
  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 회원가입
  Future<AuthToken> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final authToken = AuthToken.fromJson(data);

        // 토큰과 사용자 정보 저장
        await saveToken(authToken.token);
        await saveUserInfo(
          authToken.userId,
          authToken.username,
          authToken.email,
        );

        return authToken;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '회원가입 실패');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // 로그인
  Future<AuthToken> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final authToken = AuthToken.fromJson(data);

        // 토큰과 사용자 정보 저장
        await saveToken(authToken.token);
        await saveUserInfo(
          authToken.userId,
          authToken.username,
          authToken.email,
        );

        return authToken;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? '로그인 실패');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // 로그아웃
  Future<void> logout() async {
    await clearToken();
    await clearUserInfo();
  }

  // 현재 사용자 정보 가져오기
  Future<User> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data);
      } else {
        throw Exception('사용자 정보를 가져올 수 없습니다');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // 로그인 상태 확인
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
