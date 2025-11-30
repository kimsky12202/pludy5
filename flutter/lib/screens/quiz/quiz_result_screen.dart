// lib/screens/quiz_result_screen.dart
import 'package:flutter/material.dart';
import '../../models/quiz_models.dart';

class QuizResultScreen extends StatelessWidget {
  final Quiz quiz;
  final Map<String, dynamic> userAnswers;
  final int correctCount;

  const QuizResultScreen({
    Key? key,
    required this.quiz,
    required this.userAnswers,
    required this.correctCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final totalQuestions = quiz.questions.length;
    final percentage = (correctCount / totalQuestions * 100).round();
    final isPassed = percentage >= 60;

    return Scaffold(
      appBar: AppBar(
        title: Text('결과'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            // 결과 요약
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isPassed ? colorScheme.primary : colorScheme.secondary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    isPassed ? Icons.celebration : Icons.thumb_up,
                    size: 80,
                    color: colorScheme.onPrimary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    isPassed ? '합격!' : '수고하셨습니다!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '$correctCount / $totalQuestions',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 24,
                      color: colorScheme.onPrimary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // 상세 결과
            Text(
              '상세 결과',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),

            SizedBox(height: 16),

            ...quiz.questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              final userAnswer = userAnswers[question.id];

              bool isCorrect = false;
              String correctAnswerText = '';
              String userAnswerText = '';

              if (question.questionType == QuestionType.multipleChoice) {
                isCorrect = userAnswer == question.correctAnswerIndex;
                correctAnswerText =
                    question.answers[question.correctAnswerIndex].answerText;
                userAnswerText =
                    userAnswer != null
                        ? question.answers[userAnswer].answerText
                        : '답변 없음';
              } else {
                isCorrect = question.checkShortAnswer(userAnswer ?? '');
                correctAnswerText = question.correctAnswer ?? '';
                userAnswerText = userAnswer ?? '답변 없음';
              }

              return _buildResultCard(
                context: context,
                index: index + 1,
                question: question.questionText,
                userAnswer: userAnswerText,
                correctAnswer: correctAnswerText,
                isCorrect: isCorrect,
              );
            }).toList(),

            SizedBox(height: 24),

            // 하단 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('홈으로'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // 다시 풀기
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      '다시 풀기',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required BuildContext context,
    required int index,
    required String question,
    required String userAnswer,
    required String correctAnswer,
    required bool isCorrect,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCorrect ? colorScheme.primary : colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCorrect ? Icons.check : Icons.close,
                    color: isCorrect ? colorScheme.onPrimary : colorScheme.onError,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '질문 $index',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // 질문
            Text(
              question,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),

            SizedBox(height: 12),
            Divider(color: colorScheme.outline),
            SizedBox(height: 8),

            // 사용자 답변
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '내 답변: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                Expanded(
                  child: Text(
                    userAnswer,
                    style: TextStyle(
                      color: isCorrect ? colorScheme.primary : colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            // 정답 (틀렸을 경우만)
            if (!isCorrect) ...[
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '정답: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      correctAnswer,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
