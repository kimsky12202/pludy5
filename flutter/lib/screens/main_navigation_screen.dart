// lib/screens/main_navigation_screen.dart
import 'package:flutter/material.dart';
import './planner_screens/planner_screen.dart';
import './quiz_screen.dart';
import './chat_screen.dart';
import './fileview_screen.dart';
import './setting_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2; // 기본 인덱스를 chat(2번)으로 설정
  final GlobalKey<FileViewScreenState> _fileViewKey = GlobalKey<FileViewScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const PlannerScreen(),
      const QuizScreen(),
      ChatScreen(), // ChatScreen은 const 생성자가 없음
      FileViewScreen(key: _fileViewKey),
      const SettingScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // 파일 탭(인덱스 3)으로 전환할 때 새로고침
          if (index == 3) {
            _fileViewKey.currentState?.refresh();
          }
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '계획',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.quiz), label: '퀴즈'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '채팅'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: '파일'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
