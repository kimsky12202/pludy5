// lib/models/quiz_models.dart
import 'dart:typed_data';

// 문제 유형 enum
enum QuestionType {
  multipleChoice, // 4지선다
  shortAnswer, // 서술형
}

// 퀴즈 전체 정보
class Quiz {
  final int? id;
  final int? userId;
  final String quizName;
  final List<QuizQuestion> questions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Quiz({
    this.id,
    this.userId,
    required this.quizName,
    required this.questions,
    this.createdAt,
    this.updatedAt,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as int?,
      userId: json['user_id'] as int?,
      quizName: json['quiz_name'] as String,
      questions:
          (json['questions'] as List<dynamic>?)
              ?.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'quiz_name': quizName,
      'questions': questions.map((q) => q.toJson()).toList(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}

// 퀴즈 질문
class QuizQuestion {
  final int? id;
  final int? quizId;
  final String questionText;
  final QuestionType questionType;
  final List<QuizAnswer> answers;
  final String? correctAnswer;
  final int questionOrder;
  final DateTime? createdAt;
  final Uint8List? imageBytes;

  const QuizQuestion({
    this.id,
    this.quizId,
    required this.questionText,
    this.questionType = QuestionType.multipleChoice,
    this.answers = const [],
    this.correctAnswer,
    required this.questionOrder,
    this.createdAt,
    this.imageBytes,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final typeStr = json['question_type'] as String? ?? 'multiple_choice';
    final questionType =
        typeStr == 'short_answer'
            ? QuestionType.shortAnswer
            : QuestionType.multipleChoice;

    return QuizQuestion(
      id: json['id'] as int?,
      quizId: json['quiz_id'] as int?,
      questionText: json['question_text'] as String,
      questionType: questionType,
      answers:
          questionType == QuestionType.multipleChoice
              ? (json['answers'] as List<dynamic>?)
                      ?.map(
                        (a) => QuizAnswer.fromJson(a as Map<String, dynamic>),
                      )
                      .toList() ??
                  []
              : [],
      correctAnswer: json['correct_answer'] as String?,
      questionOrder: json['question_order'] as int? ?? 0,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      imageBytes: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (quizId != null) 'quiz_id': quizId,
      'question_text': questionText,
      'question_type':
          questionType == QuestionType.shortAnswer
              ? 'short_answer'
              : 'multiple_choice',
      if (questionType == QuestionType.multipleChoice)
        'answers': answers.map((a) => a.toJson()).toList(),
      if (questionType == QuestionType.shortAnswer && correctAnswer != null)
        'correct_answer': correctAnswer,
      'question_order': questionOrder,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  int get correctAnswerIndex {
    if (questionType == QuestionType.multipleChoice) {
      return answers.indexWhere((a) => a.isCorrect);
    }
    return -1;
  }

  bool checkShortAnswer(String userAnswer) {
    if (questionType != QuestionType.shortAnswer || correctAnswer == null) {
      return false;
    }
    final normalized1 = userAnswer.trim().toLowerCase();
    final normalized2 = correctAnswer!.trim().toLowerCase();
    return normalized1 == normalized2;
  }
}

// 퀴즈 답변
class QuizAnswer {
  final int? id;
  final int? questionId;
  final String answerText;
  final bool isCorrect;
  final int answerOrder;

  const QuizAnswer({
    this.id,
    this.questionId,
    required this.answerText,
    required this.isCorrect,
    required this.answerOrder,
  });

  factory QuizAnswer.fromJson(Map<String, dynamic> json) {
    return QuizAnswer(
      id: json['id'] as int?,
      questionId: json['question_id'] as int?,
      answerText: json['answer_text'] as String,
      isCorrect: json['is_correct'] as bool,
      answerOrder: json['answer_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (questionId != null) 'question_id': questionId,
      'answer_text': answerText,
      'is_correct': isCorrect,
      'answer_order': answerOrder,
    };
  }
}

// 사용자 진행 상황
class UserProgress {
  final int? id;
  final int userId;
  final int questionId;
  final DateTime lastAttempted;
  final int correctCount;
  final int totalAttempts;
  final DateTime? nextReviewDate;

  const UserProgress({
    this.id,
    required this.userId,
    required this.questionId,
    required this.lastAttempted,
    required this.correctCount,
    required this.totalAttempts,
    this.nextReviewDate,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      id: json['id'] as int?,
      userId: json['user_id'] as int,
      questionId: json['question_id'] as int,
      lastAttempted: DateTime.parse(json['last_attempted']),
      correctCount: json['correct_count'] as int,
      totalAttempts: json['total_attempts'] as int,
      nextReviewDate:
          json['next_review_date'] != null
              ? DateTime.parse(json['next_review_date'])
              : null,
    );
  }

  double get accuracy {
    if (totalAttempts == 0) return 0.0;
    return correctCount / totalAttempts;
  }

  bool get needsReview {
    if (nextReviewDate == null) return false;
    return DateTime.now().isAfter(nextReviewDate!);
  }
}
