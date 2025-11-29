// lib/screens/quiz_play_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/quiz_models.dart';
import 'quiz_result_screen.dart';

class QuizPlayScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizPlayScreen({Key? key, required this.quiz}) : super(key: key);

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  int _currentQuestionIndex = 0;
  final Map<int, dynamic> _userAnswers = {}; // questionId -> answer
  final TextEditingController _shortAnswerController = TextEditingController();

  @override
  void dispose() {
    _shortAnswerController.dispose();
    super.dispose();
  }

  QuizQuestion get _currentQuestion {
    return widget.quiz.questions[_currentQuestionIndex];
  }

  bool get _isLastQuestion {
    return _currentQuestionIndex == widget.quiz.questions.length - 1;
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _userAnswers[_currentQuestion.id!] = answerIndex;
    });
  }

  void _next() {
    // 서술형 답변 저장
    if (_currentQuestion.questionType == QuestionType.shortAnswer) {
      _userAnswers[_currentQuestion.id!] = _shortAnswerController.text.trim();
      _shortAnswerController.clear();
    }

    if (_isLastQuestion) {
      _finish();
    } else {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previous() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _finish() async {
    // 결과 계산
    int correctCount = 0;
    final results = <Map<String, dynamic>>[];

    for (var question in widget.quiz.questions) {
      final userAnswer = _userAnswers[question.id];
      bool isCorrect = false;

      if (question.questionType == QuestionType.multipleChoice) {
        // 4지선다
        isCorrect = userAnswer == question.correctAnswerIndex;
      } else {
        // 서술형
        isCorrect = question.checkShortAnswer(userAnswer ?? '');
      }

      if (isCorrect) correctCount++;

      results.add({'question_id': question.id, 'is_correct': isCorrect});
    }

    // 진행 상황 제출
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.isLoggedIn) {
      await userProvider.submitQuizProgress(
        quizId: widget.quiz.id!,
        results: results,
      );
    }

    // 결과 화면으로 이동
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => QuizResultScreen(
                quiz: widget.quiz,
                userAnswers: _userAnswers,
                correctCount: correctCount,
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async {
        return await _showExitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.quizName),
          actions: [
            Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentQuestionIndex + 1}/${widget.quiz.questions.length}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // 진행 바
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / widget.quiz.questions.length,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 질문
                    Text(
                      '질문 ${_currentQuestionIndex + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _currentQuestion.questionText,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 32),

                    // 답변 입력
                    if (_currentQuestion.questionType ==
                        QuestionType.multipleChoice)
                      _buildMultipleChoiceOptions()
                    else
                      _buildShortAnswerInput(),
                  ],
                ),
              ),
            ),

            // 하단 버튼
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 이전 버튼
                  if (_currentQuestionIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previous,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('이전'),
                      ),
                    ),
                  if (_currentQuestionIndex > 0) SizedBox(width: 12),

                  // 다음/완료 버튼
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _canProceed() ? _next : null,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _isLastQuestion ? '완료' : '다음',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceOptions() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children:
          _currentQuestion.answers.asMap().entries.map((entry) {
            final index = entry.key;
            final answer = entry.value;
            final isSelected = _userAnswers[_currentQuestion.id] == index;

            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _selectAnswer(index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primaryContainer : colorScheme.surface,
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : colorScheme.outline,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color:
                              isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index), // A, B, C, D
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          answer.answerText,
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                isSelected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildShortAnswerInput() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextField(
      controller: _shortAnswerController,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: '답변을 입력하세요',
        labelStyle: TextStyle(color: colorScheme.secondary),
        hintText: '여기에 답변을 입력하세요',
        hintStyle: TextStyle(color: colorScheme.secondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surface,
      ),
      maxLines: 3,
      onChanged: (value) {
        setState(() {});
      },
    );
  }

  bool _canProceed() {
    if (_currentQuestion.questionType == QuestionType.multipleChoice) {
      return _userAnswers.containsKey(_currentQuestion.id);
    } else {
      return _shortAnswerController.text.trim().isNotEmpty;
    }
  }

  Future<bool> _showExitDialog() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: colorScheme.surface,
                title: Text('퀴즈 종료', style: TextStyle(color: colorScheme.onSurface)),
                content: Text(
                  '퀴즈를 종료하시겠습니까?\n진행 상황이 저장되지 않습니다.',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('취소', style: TextStyle(color: colorScheme.secondary)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('종료', style: TextStyle(color: colorScheme.error)),
                  ),
                ],
              ),
        ) ??
        false;
  }
}
