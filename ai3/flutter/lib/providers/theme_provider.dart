// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  // 기본값: 라이트 모드 (ThemeMode.system으로 하면 기기 설정을 따라갑니다)
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  // 현재 다크모드인지 확인 (스위치 상태용)
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // 테마 변경 함수
  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // 앱 전체에 변경 알림
  }
}
