// lib/services/planner_services/timetable_settings_service.dart
// 시간표 커스터마이징 설정 저장 서비스
import 'package:shared_preferences/shared_preferences.dart';

class TimetableSettingsService {
  static const String _fontFamilyKey = 'timetable_font_family';
  static const String _penTypeKey = 'timetable_pen_type';

  // 기본값
  static const String defaultFontFamily = '기본';
  static const String defaultPenType = '볼펜';

  /// 글씨체 가져오기
  static Future<String> getFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fontFamilyKey) ?? defaultFontFamily;
  }

  /// 글씨체 저장
  static Future<void> setFontFamily(String fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, fontFamily);
  }

  /// 펜 종류 가져오기
  static Future<String> getPenType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_penTypeKey) ?? defaultPenType;
  }

  /// 펜 종류 저장
  static Future<void> setPenType(String penType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_penTypeKey, penType);
  }
}

