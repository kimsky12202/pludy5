// lib/screens/quiz_create_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/quiz_models.dart';
import 'ai_quiz_generate_screen.dart'; // 추가!

class QuizCreateScreen extends StatefulWidget {
  const QuizCreateScreen({Key? key}) : super(key: key);

  @override
  State<QuizCreateScreen> createState() => _QuizCreateScreenState();
}

class _QuizCreateScreenState extends State<QuizCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quizNameController = TextEditingController();
  final List<QuestionFormData> _questions = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _addQuestion();
  }

  @override
  void dispose() {
    _quizNameController.dispose();
    for (var question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(QuestionFormData());
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('모든 필드를 올바르게 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('최소 1개의 질문이 필요합니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      final questions =
          _questions.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;

            if (data.questionType == QuestionType.multipleChoice) {
              final answers = [
                QuizAnswer(
                  answerText: data.answer1Controller.text.trim(),
                  isCorrect: data.correctAnswerIndex == 0,
                  answerOrder: 0,
                ),
                QuizAnswer(
                  answerText: data.answer2Controller.text.trim(),
                  isCorrect: data.correctAnswerIndex == 1,
                  answerOrder: 1,
                ),
                QuizAnswer(
                  answerText: data.answer3Controller.text.trim(),
                  isCorrect: data.correctAnswerIndex == 2,
                  answerOrder: 2,
                ),
                QuizAnswer(
                  answerText: data.answer4Controller.text.trim(),
                  isCorrect: data.correctAnswerIndex == 3,
                  answerOrder: 3,
                ),
              ];

              return QuizQuestion(
                questionText: data.questionController.text.trim(),
                questionType: QuestionType.multipleChoice,
                answers: answers,
                questionOrder: index,
              );
            } else {
              return QuizQuestion(
                questionText: data.questionController.text.trim(),
                questionType: QuestionType.shortAnswer,
                correctAnswer: data.shortAnswerController.text.trim(),
                questionOrder: index,
              );
            }
          }).toList();

      final quiz = await userProvider.createQuiz(
        _quizNameController.text.trim(),
        questions,
      );

      if (quiz != null && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('퀴즈가 생성되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('퀴즈 생성에 실패했습니다'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('퀴즈 만들기'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // AI 생성 버튼 추가!
          IconButton(
            icon: Icon(Icons.auto_awesome),
            tooltip: 'AI로 퀴즈 생성',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AIQuizGenerateScreen(),
                ),
              );

              if (result == true && mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // 퀴즈 제목
            TextFormField(
              controller: _quizNameController,
              decoration: InputDecoration(
                labelText: '퀴즈 제목',
                hintText: '예: 영어 단어 퀴즈',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '퀴즈 제목을 입력하세요';
                }
                return null;
              },
            ),

            SizedBox(height: 24),

            // 질문 목록
            ..._questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              return _buildQuestionCard(index, question);
            }).toList(),

            SizedBox(height: 16),

            // 질문 추가 버튼
            OutlinedButton.icon(
              onPressed: _addQuestion,
              icon: Icon(Icons.add),
              label: Text('질문 추가'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.blue),
              ),
            ),

            SizedBox(height: 24),

            // 제출 버튼
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isSubmitting
                      ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        '퀴즈 생성',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, QuestionFormData question) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '질문 ${index + 1}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    // 문제 유형 선택
                    DropdownButton<QuestionType>(
                      value: question.questionType,
                      items: [
                        DropdownMenuItem(
                          value: QuestionType.multipleChoice,
                          child: Text('4지선다'),
                        ),
                        DropdownMenuItem(
                          value: QuestionType.shortAnswer,
                          child: Text('서술형'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          question.questionType = value!;
                        });
                      },
                    ),
                    SizedBox(width: 8),
                    // 삭제 버튼
                    if (_questions.length > 1)
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeQuestion(index),
                      ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 16),

            // 질문
            TextFormField(
              controller: question.questionController,
              decoration: InputDecoration(
                labelText: '질문',
                hintText: '질문을 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '질문을 입력하세요';
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            // 문제 유형에 따른 답변 입력
            if (question.questionType == QuestionType.multipleChoice)
              _buildMultipleChoiceAnswers(question)
            else
              _buildShortAnswer(question),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceAnswers(QuestionFormData question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '선택지 (정답 선택)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),
        ...[0, 1, 2, 3].map((index) {
          final controllers = [
            question.answer1Controller,
            question.answer2Controller,
            question.answer3Controller,
            question.answer4Controller,
          ];

          return Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Radio<int>(
                  value: index,
                  groupValue: question.correctAnswerIndex,
                  onChanged: (value) {
                    setState(() {
                      question.correctAnswerIndex = value!;
                    });
                  },
                ),
                Expanded(
                  child: TextFormField(
                    controller: controllers[index],
                    decoration: InputDecoration(
                      hintText: '선택지 ${index + 1}',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '선택지를 입력하세요';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildShortAnswer(QuestionFormData question) {
    return TextFormField(
      controller: question.shortAnswerController,
      decoration: InputDecoration(
        labelText: '정답',
        hintText: '정답을 입력하세요',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '정답을 입력하세요';
        }
        return null;
      },
    );
  }
}

class QuestionFormData {
  QuestionType questionType = QuestionType.multipleChoice;
  final TextEditingController questionController = TextEditingController();

  final TextEditingController answer1Controller = TextEditingController();
  final TextEditingController answer2Controller = TextEditingController();
  final TextEditingController answer3Controller = TextEditingController();
  final TextEditingController answer4Controller = TextEditingController();
  int correctAnswerIndex = 0;

  final TextEditingController shortAnswerController = TextEditingController();

  void dispose() {
    questionController.dispose();
    answer1Controller.dispose();
    answer2Controller.dispose();
    answer3Controller.dispose();
    answer4Controller.dispose();
    shortAnswerController.dispose();
  }
}
