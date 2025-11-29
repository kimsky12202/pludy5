// 통합된 main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// 팀원 import
import 'screens/main_navigation_screen.dart';
import 'screens/auth_screen.dart';
import 'services/auth.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Pludy',
            debugShowCheckedModeBanner: false,

            // 테마 모드 적용
            themeMode: themeProvider.themeMode,

            // ☀️ 라이트 테마 (Black & White)
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.grey.shade50,

              colorScheme: ColorScheme.light(
                primary: Colors.black,
                secondary: Colors.grey.shade600,
                surface: Colors.white,
                error: Colors.redAccent,
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: Colors.black,
                onError: Colors.white,
                outline: Colors.grey.shade400,
                primaryContainer: Colors.grey.shade100,
                onPrimaryContainer: Colors.black,
              ),

              appBarTheme: AppBarTheme(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 2,
                centerTitle: true,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
              ),

              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: BorderSide(color: Colors.black, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
              ),

              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            // 🌙 다크 테마 (White & Black)
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.grey.shade900,

              colorScheme: ColorScheme.dark(
                primary: Colors.white,
                secondary: Colors.grey.shade400,
                surface: Colors.grey.shade800,
                error: Colors.redAccent,
                onPrimary: Colors.black,
                onSecondary: Colors.black,
                onSurface: Colors.white,
                onError: Colors.black,
                outline: Colors.grey.shade600,
                primaryContainer: Colors.grey.shade700,
                onPrimaryContainer: Colors.white,
              ),

              appBarTheme: AppBarTheme(
                backgroundColor: Colors.grey.shade900,
                foregroundColor: Colors.white,
                elevation: 2,
                centerTitle: true,
              ),

              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
              ),

              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
              ),

              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade600),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade600),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade800,
              ),
            ),

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
        },
      ),
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

    // 로그인된 경우 UserProvider 초기화
    if (loggedIn && mounted) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.initialize();
    }

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