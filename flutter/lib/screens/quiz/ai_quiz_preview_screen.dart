// lib/screens/ai_quiz_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/ai_quiz_service.dart';
import '../models/quiz_models.dart';

class AIQuizPreviewScreen extends StatefulWidget {
  final List<dynamic> questions;
  final String fileName;

  const AIQuizPreviewScreen({
    super.key,
    required this.questions,
    required this.fileName,
  });

  @override
  State<AIQuizPreviewScreen> createState() => _AIQuizPreviewScreenState();
}

class _AIQuizPreviewScreenState extends State<AIQuizPreviewScreen> {
  final AIQuizService _aiQuizService = AIQuizService();
  final TextEditingController _quizNameController = TextEditingController();
  bool _isSaving = false;
  List<dynamic> _questions = [];

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.questions);
    _quizNameController.text = widget.fileName.replaceAll('.pdf', '');
  }

  @override
  void dispose() {
    _quizNameController.dispose();
    super.dispose();
  }

  // [수정된 부분] 저장 함수: 로그인 체크 추가
  Future<void> _saveQuiz() async {
    // 1. 퀴즈 이름 확인
    if (_quizNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('퀴즈 이름을 입력하세요'),
          backgroundColor: Colors.grey.shade900,
        ),
      );
      return;
    }

    // 2. 로그인 정보 안전하게 확인
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (userProvider.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그인 정보가 없습니다. 앱을 다시 실행하거나 재로그인 해주세요.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _aiQuizService.saveQuiz(
        quizName: _quizNameController.text.trim(),
        questions: _questions,
        userId: userProvider.userId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('퀴즈가 저장되었습니다'), backgroundColor: Colors.black),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('퀴즈 저장 실패: $e'),
            backgroundColor: Colors.grey.shade900,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _deleteQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('문제가 삭제되었습니다'), backgroundColor: Colors.black),
    );
  }

  void _editQuestion(int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final question = _questions[index];
    final questionController = TextEditingController(
      text: question['question_text']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              '문제 수정',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: questionController,
              maxLines: 3,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: '문제',
                labelStyle: TextStyle(color: colorScheme.secondary),
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
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '취소',
                  style: TextStyle(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _questions[index]['question_text'] =
                        questionController.text;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('문제가 수정되었습니다'),
                      backgroundColor: colorScheme.primary,
                    ),
                  );
                },
                child: Text(
                  '저장',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('퀴즈 미리보기', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_questions.length}개 문제',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 퀴즈 이름 입력
          Container(
            padding: EdgeInsets.all(16),
            color: colorScheme.surface,
            child: TextField(
              controller: _quizNameController,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: '퀴즈 이름',
                labelStyle: TextStyle(
                  color: colorScheme.secondary,
                  fontSize: 16,
                ),
                prefixIcon: Icon(Icons.edit, color: colorScheme.primary),
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
                fillColor: theme.scaffoldBackgroundColor,
              ),
            ),
          ),

          Divider(height: 1, color: colorScheme.outline),

          // 문제 목록
          Expanded(
            child:
                _questions.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.quiz_outlined,
                            size: 64,
                            color: colorScheme.outline,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '문제가 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        final question = _questions[index];
                        return _buildQuestionCard(question, index);
                      },
                    ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              offset: Offset(0, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '취소',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving || _questions.isEmpty ? null : _saveQuiz,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isSaving
                          ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: colorScheme.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            '퀴즈 저장',
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
      ),
    );
  }

  Widget _buildQuestionCard(dynamic question, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final questionType = question['question_type'];
    final isMultipleChoice = questionType == 'multiple_choice';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      color: colorScheme.surface,
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 문제 헤더
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '문제 ${index + 1}',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isMultipleChoice ? '4지선다' : '서술형',
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 20),
                  color: colorScheme.secondary,
                  onPressed: () => _editQuestion(index),
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(),
                ),
                SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20),
                  color: colorScheme.secondary,
                  onPressed: () => _deleteQuestion(index),
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(),
                ),
              ],
            ),

            SizedBox(height: 12),

            // 문제 내용
            Text(
              question['question_text']?.toString() ?? '',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                height: 1.4,
              ),
            ),

            SizedBox(height: 12),

            // 선택지 또는 정답
            if (isMultipleChoice) ...[
              ...((question['answers'] ?? []) as List).asMap().entries.map((
                entry,
              ) {
                final idx = entry.key;
                final answer = entry.value;
                final isCorrect = answer['is_correct'] == true;

                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCorrect ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCorrect ? colorScheme.primary : colorScheme.outline,
                      width: isCorrect ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isCorrect ? colorScheme.onPrimary : colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCorrect ? colorScheme.onPrimary : colorScheme.outline,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCorrect ? colorScheme.primary : colorScheme.secondary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          answer['answer_text']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: isCorrect ? colorScheme.onPrimary : colorScheme.onSurface,
                            fontWeight:
                                isCorrect ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isCorrect)
                        Icon(Icons.check_circle, color: colorScheme.onPrimary, size: 20),
                    ],
                  ),
                );
              }).toList(),
            ] else ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.primary, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: colorScheme.onPrimary, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question['correct_answer']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
