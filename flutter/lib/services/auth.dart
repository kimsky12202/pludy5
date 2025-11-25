// lib/services/auth.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AuthService {
  static final String baseUrl = AppConfig.baseUrl;
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // 로그인
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);

          // 토큰 저장
          await _saveToken(data['access_token']);

          // 사용자 정보 저장
          await _saveUserData(data['user']);

          return {
            'success': true,
            'token': data['access_token'],
            'user': data['user'],
          };
        } catch (e) {
          print('JSON 파싱 오류: $e');
          return {'success': false, 'message': '서버 응답 형식 오류가 발생했습니다.'};
        }
      } else {
        // 에러 응답 처리
        String errorMessage = '로그인에 실패했습니다.';
        try {
          final contentType = response.headers['content-type'] ?? '';
          print('응답 Content-Type: $contentType');
          print('응답 상태 코드: ${response.statusCode}');
          print('응답 본문: ${response.body}');

          if (contentType.contains('application/json')) {
            final error = json.decode(response.body);
            errorMessage = error['detail'] ?? errorMessage;
            print('서버 에러 메시지: $errorMessage');
          } else {
            // HTML 에러 페이지인 경우
            if (response.statusCode >= 500) {
              errorMessage = '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
            } else if (response.statusCode == 401) {
              errorMessage = '이메일 또는 비밀번호가 올바르지 않습니다.';
            } else {
              errorMessage = '로그인에 실패했습니다. (${response.statusCode})';
            }
          }
        } catch (e) {
          print('에러 응답 파싱 오류: $e');
          print('원본 응답: ${response.body}');
          if (response.statusCode >= 500) {
            errorMessage = '서버 오류가 발생했습니다.';
          }
        }
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      print('로그인 오류: $e');
      String errorMessage = '네트워크 오류가 발생했습니다.';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = '서버 연결 시간이 초과되었습니다. 서버가 실행 중인지 확인해주세요.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = '서버에 연결할 수 없습니다. 네트워크 연결을 확인해주세요.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = '서버 응답 형식 오류가 발생했습니다. 서버 상태를 확인해주세요.';
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  // 회원가입
  static Future<Map<String, dynamic>> register(
    String email,
    String username,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'email': email,
              'username': username,
              'password': password,
            }),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          return {'success': true, 'message': '회원가입이 완료되었습니다.', 'user': data};
        } catch (e) {
          print('JSON 파싱 오류: $e');
          return {'success': false, 'message': '서버 응답 형식 오류가 발생했습니다.'};
        }
      } else {
        // 에러 응답 처리
        String errorMessage = '회원가입에 실패했습니다.';
        try {
          final contentType = response.headers['content-type'] ?? '';
          print('응답 Content-Type: $contentType');
          print('응답 상태 코드: ${response.statusCode}');
          print('응답 본문: ${response.body}');

          if (contentType.contains('application/json')) {
            final error = json.decode(response.body);
            errorMessage = error['detail'] ?? errorMessage;
            print('서버 에러 메시지: $errorMessage');
          } else {
            // HTML 에러 페이지인 경우
            if (response.statusCode >= 500) {
              errorMessage = '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
            } else if (response.statusCode == 400) {
              errorMessage = '입력 정보를 확인해주세요. (이메일 중복 등)';
            } else {
              errorMessage = '회원가입에 실패했습니다. (${response.statusCode})';
            }
          }
        } catch (e) {
          print('에러 응답 파싱 오류: $e');
          print('원본 응답: ${response.body}');
          if (response.statusCode >= 500) {
            errorMessage = '서버 오류가 발생했습니다.';
          }
        }
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      print('회원가입 오류: $e');
      String errorMessage = '네트워크 오류가 발생했습니다.';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = '서버 연결 시간이 초과되었습니다. 서버가 실행 중인지 확인해주세요.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = '서버에 연결할 수 없습니다. 네트워크 연결을 확인해주세요.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = '서버 응답 형식 오류가 발생했습니다. 서버 상태를 확인해주세요.';
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  // 토큰 저장
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // 사용자 정보 저장
  static Future<void> _saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(user));
  }

  // 저장된 토큰 가져오기
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // 저장된 사용자 정보 가져오기
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return json.decode(userJson);
    }
    return null;
  }

  // 로그인 상태 확인
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // 로그아웃
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // 인증 헤더 가져오기 (API 호출 시 사용)
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    
    if (token != null) {
      print('🔑 전송할 헤더:');
      print('   Content-Type: application/json');
      print('   Authorization: Bearer ${token.substring(0, 20)}...');
    }
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',  // Bearer 띄어쓰기 확인
    };
  }
}
