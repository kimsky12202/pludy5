// 통합된 main.dart
import 'package:flutter/material.dart';
// 팀원 import
import 'screens/main_navigation_screen.dart';
import 'screens/auth_screen.dart';
import 'services/auth.dart';

// 내 파인만 화면 import (추가)
import 'screens/ai_screen/knowledge_check_screen.dart';
import 'screens/ai_screen/first_explanation_screen.dart';
import 'screens/ai_screen/first_reflection_screen.dart';
import 'screens/ai_screen/ai_explanation_screen.dart';
import 'screens/ai_screen/second_explanation_screen.dart';
import 'screens/ai_screen/second_reflection_screen.dart';
import 'screens/ai_screen/evaluation_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pludy',
      theme: ThemeData(
        primaryColor: Colors.black,
        useMaterial3: true,
        appBarTheme: AppBarTheme(elevation: 2, centerTitle: true),
      ),
      debugShowCheckedModeBanner: false,
      
      // 팀원: AuthWrapper 사용
      home: AuthWrapper(),
      
      routes: {
        '/home': (context) => const MainNavigationScreen(),
      },
      
      // 통합: 팀원 라우트 제거, 내 파인만 라우트 추가
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;
        
        switch (settings.name) {
          // 내 파인만 라우트 (7개)
          case '/knowledge_check':
            return MaterialPageRoute(
              builder: (context) => KnowledgeCheckScreen(
                concept: args!['concept'],
                roomId: args['roomId'],
              ),
            );
            
          case '/first_explanation':
            return MaterialPageRoute(
              builder: (context) => FirstExplanationScreen(
                concept: args!['concept'],
                roomId: args['roomId'],
              ),
            );
            
          case '/first_reflection':
            return MaterialPageRoute(
              builder: (context) => FirstReflectionScreen(
                concept: args!['concept'],
                roomId: args['roomId'],
                explanation: args['explanation'],
              ),
            );
            
          case '/ai_explanation':
            return MaterialPageRoute(
              builder: (context) => AIExplanationScreen(
                roomId: args!['roomId'],
                concept: args['concept'],
                explanation: args['explanation'],
                reflection: args['reflection'],
              ),
            );
            
          case '/second_explanation':
            return MaterialPageRoute(
              builder: (context) => SecondExplanationScreen(
                concept: args!['concept'],
                roomId: args['roomId'],
                firstExplanation: args['firstExplanation'],
                firstReflection: args['firstReflection'],
              ),
            );
            
          case '/second_reflection':
            return MaterialPageRoute(
              builder: (context) => SecondReflectionScreen(
                concept: args!['concept'],
                roomId: args['roomId'],
                firstExplanation: args['firstExplanation'],
                firstReflection: args['firstReflection'],
                secondExplanation: args['secondExplanation'],
              ),
            );
            
          case '/evaluation':
            return MaterialPageRoute(
              builder: (context) => EvaluationScreen(
                roomId: args!['roomId'],
                concept: args['concept'],
                firstExplanation: args['firstExplanation'],
                firstReflection: args['firstReflection'],
                secondExplanation: args['secondExplanation'],
                secondReflection: args['secondReflection'],
              ),
            );
        }
        
        return null;
      },
    );
  }
}

// 팀원의 AuthWrapper 그대로 사용
class AuthWrapper extends StatefulWidget {
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final loggedIn = await AuthService.isLoggedIn();
    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _isLoggedIn
        ? const MainNavigationScreen()
        : const LoginScreen();
  }
}