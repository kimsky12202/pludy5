// lib/screens/quiz_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quiz_models.dart';
import '../providers/user_provider.dart';

class QuizEditScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizEditScreen({super.key, required this.quiz});

  @override
  State<QuizEditScreen> createState() => _QuizEditScreenState();
}

class _QuizEditScreenState extends State<QuizEditScreen> {
  // 화면 진입 시 질문 목록을 복사해둠
  late List<QuizQuestion> _questions;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.quiz.questions);
  }

  // 수정 팝업 띄우기
  void _showEditDialog(int index) {
    final question = _questions[index];
    final textController = TextEditingController(text: question.questionText);

    // 서술형 정답이 있다면 컨트롤러 연결
    final shortAnswerController = TextEditingController(
      text: question.correctAnswer ?? '',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('질문 수정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  decoration: InputDecoration(
                    labelText: '질문 내용',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 16),
                if (question.questionType == QuestionType.shortAnswer)
                  TextField(
                    controller: shortAnswerController,
                    decoration: InputDecoration(
                      labelText: '정답 (서술형)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                // TODO: 객관식 보기 수정 UI는 이곳에 추가 구현 가능
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // 1. 수정된 내용으로 객체 생성
                  final updatedQuestion = QuizQuestion(
                    id: question.id,
                    quizId: question.quizId,
                    questionText: textController.text,
                    questionType: question.questionType,
                    questionOrder: question.questionOrder,
                    answers: question.answers, // 보기는 일단 유지
                    correctAnswer:
                        question.questionType == QuestionType.shortAnswer
                            ? shortAnswerController.text
                            : question.correctAnswer,
                  );

                  // 2. Provider를 통해 서버에 전송
                  final success = await Provider.of<UserProvider>(
                    context,
                    listen: false,
                  ).updateQuestion(question.id!, updatedQuestion);

                  if (success && mounted) {
                    setState(() {
                      _questions[index] = updatedQuestion;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('수정되었습니다!')));
                  }
                },
                child: Text('저장'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.quiz.quizName} 수정'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: _questions.length,
        separatorBuilder: (context, index) => SizedBox(height: 12),
        itemBuilder: (context, index) {
          final q = _questions[index];
          return Card(
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.black,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                q.questionText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                q.questionType == QuestionType.multipleChoice ? '4지선다' : '서술형',
              ),
              trailing: IconButton(
                icon: Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _showEditDialog(index),
              ),
            ),
          );
        },
      ),
    );
  }
}
