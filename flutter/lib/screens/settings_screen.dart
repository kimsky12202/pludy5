// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/theme_provider.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    // [수정 1] 다크모드 여부에 따른 색상 정의
    final isDark = themeProvider.isDarkMode;
    final backgroundColor = isDark ? Colors.black : Colors.white; // 배경색
    final textColor = isDark ? Colors.white : Colors.black; // 기본 글자색
    final iconColor = isDark ? Colors.white : Colors.black; // 기본 아이콘색

    // [수정 2] Scaffold로 감싸고 AppBar 추가
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: Container(
        color: backgroundColor, // 여기가 핵심입니다! (배경을 어둡게 변경)
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // 다크모드 스위치
            SwitchListTile(
              title: Text(
                '다크 모드',
                style: TextStyle(color: textColor), // 글자색 적용
              ),
              subtitle: Text(
                '어두운 테마를 사용합니다',
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
              secondary: Icon(Icons.dark_mode, color: iconColor), // 아이콘색 적용
              value: isDark,
              activeColor: Colors.white,
              activeTrackColor: Colors.grey.shade700,
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.grey.shade300,
              onChanged: (value) => themeProvider.toggleTheme(value),
            ),

            Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),

            // 로그아웃
            ListTile(
              leading: Icon(Icons.logout, color: iconColor), // 아이콘색 적용
              title: Text(
                '로그아웃',
                style: TextStyle(color: textColor), // 글자색 적용
              ),
              onTap: () async {
                await userProvider.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),

            // 계정 삭제 (빨간색 유지)
            ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text('계정 삭제', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await userProvider.deleteAccount();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
