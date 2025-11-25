// lib/screens/setting_screens/setting_screens.dart
import 'package:flutter/material.dart';
import '../../services/auth.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  /// 로그아웃 처리 함수
  /// 저장된 토큰과 사용자 정보를 삭제하고 로그인 화면으로 이동
  Future<void> _handleLogout(BuildContext context) async {
    // 확인 다이얼로그 표시
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('로그아웃'),
            content: const Text('정말 로그아웃 하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    // 사용자가 확인을 누른 경우에만 로그아웃 처리
    if (shouldLogout == true && context.mounted) {
      // AuthService를 통해 로그아웃 (토큰 및 사용자 정보 삭제)
      await AuthService.logout();

      // 로그인 화면으로 이동
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 로그아웃 버튼 섹션
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout),
            label: const Text('로그아웃', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
