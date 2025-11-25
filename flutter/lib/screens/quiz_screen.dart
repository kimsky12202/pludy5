// lib/screens/quiz_screens/quiz_screens.dart
import 'package:flutter/material.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('퀴즈')),
      body: const Center(child: Text('퀴즈 화면', style: TextStyle(fontSize: 24))),
    );
  }
}
