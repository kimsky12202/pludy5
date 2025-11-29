import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/app_config.dart';
import 'auth_service.dart';

class AIQuizService {
  final AuthService _authService = AuthService();

  /// PDF 파일 선택
  Future<dynamic> pickPDFFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb,
      );

      if (result != null) {
        if (kIsWeb) {
          return result.files.first;
        } else {
          return File(result.files.single.path!);
        }
      }
      return null;
    } catch (e) {
      throw Exception('파일 선택 오류: $e');
    }
  }

  /// PDF에서 AI 퀴즈 생성
  Future<List<dynamic>> generateQuizFromPDF({
    required dynamic pdfFile,
    required int numQuestions,
    required String questionTypes,
  }) async {
    try {
      final token = await _authService.getToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/api/quizzes/generate-from-pdf'),
      );

      // 헤더 추가
      request.headers['Authorization'] = 'Bearer $token';

      // 파일 추가
      if (kIsWeb) {
        final platformFile = pdfFile as PlatformFile;
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            platformFile.bytes!,
            filename: platformFile.name,
          ),
        );
      } else {
        final file = pdfFile as File;
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      // 폼 데이터 추가
      request.fields['num_questions'] = numQuestions.toString();
      request.fields['question_types'] = questionTypes;

      print('🔍 Flutter: Sending request...');
      print('🔍 num_questions: $numQuestions');
      print('🔍 question_types: $questionTypes');

      // 요청 전송
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('🔍 Flutter: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 Flutter: Questions received: ${data['questions'].length}');
        return data['questions'];
      } else {
        throw Exception('퀴즈 생성 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('퀴즈 생성 오류: $e');
    }
  }

  /// 퀴즈 저장
  Future<void> saveQuiz({
    required String quizName,
    required List<dynamic> questions,
    required int userId,
  }) async {
    try {
      final token = await _authService.getToken();

      // 질문 데이터 변환
      final formattedQuestions =
          questions.asMap().entries.map((entry) {
            final index = entry.key;
            final q = entry.value;

            if (q['question_type'] == 'multiple_choice') {
              return {
                'question_text': q['question_text'],
                'question_type': 'multiple_choice',
                'question_order': index,  // 인덱스로 순서 설정
                'answers':
                    (q['answers'] as List)
                        .map(
                          (a) => {
                            'answer_text': a['answer_text'],
                            'is_correct': a['is_correct'] ?? false,
                            'answer_order': a['answer_order'] ?? 0,
                          },
                        )
                        .toList(),
              };
            } else {
              return {
                'question_text': q['question_text'],
                'question_type': 'short_answer',
                'question_order': index,  // 인덱스로 순서 설정
                'correct_answer': q['correct_answer'],
              };
            }
          }).toList();

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/quizzes'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'quiz_name': quizName,
          // user_id 제거: 서버가 JWT 토큰에서 자동으로 가져옴
          'questions': formattedQuestions,
        }),
      );

      print('🔍 Save Quiz Response: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ Save Quiz Error: ${response.body}');
        throw Exception('퀴즈 저장 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('퀴즈 저장 오류: $e');
    }
  }
}
