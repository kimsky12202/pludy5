// lib/screens/planner_screens/planner_screens.dart
import 'package:flutter/material.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('학습 계획'),
      ),
      body: const Center(
        child: Text(
          '학습 계획 화면',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

