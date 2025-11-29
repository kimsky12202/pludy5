// lib/screens/main_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'quiz_home_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart'; // [필수] 설정 화면 불러오기

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;

  // [수정] 3개의 화면 리스트 (파인만, 퀴즈, 설정)
  final List<Widget> _screens = [
    ChatScreen(),
    QuizHomeScreen(),
    SettingsScreen(),
  ];

  // [수정] 3개의 화면 제목
  final List<String> _titles = ['파인만 학습', '퀴즈', '설정'];

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 우측 상단 톱니바퀴 제거됨

          // 사용자 이름 배지
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, color: Colors.black, size: 16),
                    SizedBox(width: 6),
                    Text(
                      userProvider.username ?? 'User',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // 현재 선택된 탭의 화면 보여주기
      body: _screens[_currentIndex],

      // [수정] 하단 내비게이션 바 (3개 탭)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: Offset(0, -1),
              blurRadius: 4,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: '파인만 학습',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.quiz_outlined,
                  activeIcon: Icons.quiz,
                  label: '퀴즈',
                  index: 1,
                ),
                // [추가됨] 설정 탭
                _buildNavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: '설정',
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 탭 버튼 디자인 위젯
  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 내용물 크기만큼만 차지
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? Colors.white : Colors.grey.shade600,
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
