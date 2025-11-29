// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  // 기본값: 라이트 모드 (ThemeMode.system으로 하면 기기 설정을 따라갑니다)
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  // 현재 다크모드인지 확인 (스위치 상태용)
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // 초기화 - 저장된 테마 설정 불러오기
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey) ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // 테마 변경 함수
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

    // SharedPreferences에 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);

    notifyListeners(); // 앱 전체에 변경 알림
  }
}
