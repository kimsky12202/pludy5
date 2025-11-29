// lib/screens/ai_quiz_generate_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/ai_quiz_service.dart';
import 'ai_quiz_preview_screen.dart';

class AIQuizGenerateScreen extends StatefulWidget {
  const AIQuizGenerateScreen({super.key});

  @override
  State<AIQuizGenerateScreen> createState() => _AIQuizGenerateScreenState();
}

class _AIQuizGenerateScreenState extends State<AIQuizGenerateScreen> {
  final AIQuizService _aiQuizService = AIQuizService();

  dynamic _selectedFile;
  String? _selectedFileName;
  bool _isGenerating = false;
  int _numQuestions = 5;
  String _questionTypes = 'mixed';

  Future<void> _pickFile() async {
    try {
      final file = await _aiQuizService.pickPDFFile();
      if (file != null) {
        setState(() {
          _selectedFile = file;
          if (kIsWeb) {
            _selectedFileName = (file as PlatformFile).name;
          } else {
            _selectedFileName = (file as File).path.split('/').last;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('파일 선택 오류: $e'),
            backgroundColor: Colors.grey.shade900,
          ),
        );
      }
    }
  }

  Future<void> _generateQuiz() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF 파일을 먼저 선택하세요'),
          backgroundColor: Colors.grey.shade700,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final questions = await _aiQuizService.generateQuizFromPDF(
        pdfFile: _selectedFile!,
        numQuestions: _numQuestions,
        questionTypes: _questionTypes,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => AIQuizPreviewScreen(
                  questions: questions,
                  fileName: _selectedFileName ?? 'quiz.pdf',
                ),
          ),
        ).then((result) {
          if (result == true) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI 퀴즈 생성 실패: $e'),
            backgroundColor: Colors.grey.shade900,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('AI 퀴즈 생성'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 설명
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: colorScheme.primary, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'PDF 파일을 업로드하면\nAI가 자동으로 퀴즈를 만들어줍니다!',
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // PDF 파일 선택
            Text(
              'PDF 파일 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),

            InkWell(
              onTap: _isGenerating ? null : _pickFile,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedFile != null ? colorScheme.primary : colorScheme.outline,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _selectedFile != null
                      ? colorScheme.primaryContainer
                      : colorScheme.surface,
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null ? Icons.check_circle : Icons.upload_file,
                      size: 48,
                      color: _selectedFile != null ? colorScheme.primary : colorScheme.secondary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      _selectedFile != null
                          ? _selectedFileName ?? '파일 선택됨'
                          : 'PDF 파일 선택하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _selectedFile != null ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 32),

            // 문제 개수 선택
            Text(
              '생성할 문제 개수',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),

            Slider(
              value: _numQuestions.toDouble(),
              min: 3,
              max: 20,
              divisions: 17,
              label: '$_numQuestions개',
              activeColor: colorScheme.primary,
              inactiveColor: colorScheme.outline,
              onChanged:
                  _isGenerating
                      ? null
                      : (value) {
                        setState(() {
                          _numQuestions = value.toInt();
                        });
                      },
            ),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_numQuestions개의 문제',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ),

            SizedBox(height: 32),

            // 문제 유형 선택
            Text(
              '문제 유형',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _buildTypeButton('혼합', 'mixed', Icons.shuffle)),
                SizedBox(width: 8),
                Expanded(
                  child: _buildTypeButton(
                    '4지선다',
                    'multiple_choice',
                    Icons.radio_button_checked,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildTypeButton(
                    '서술형',
                    'short_answer',
                    Icons.edit_note,
                  ),
                ),
              ],
            ),

            SizedBox(height: 48),

            // 생성 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateQuiz,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isGenerating
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'AI가 문제를 생성하는 중...',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        )
                        : Text(
                          'AI 퀴즈 생성하기',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),

            if (_isGenerating) ...[
              SizedBox(height: 24),
              Center(
                child: Text(
                  _numQuestions <= 10
                      ? '⏳ 1-2분 정도 소요될 수 있습니다'
                      : '⏳ 3-5분 정도 소요될 수 있습니다 (문제 수: $_numQuestions개)',
                  style: TextStyle(fontSize: 14, color: colorScheme.secondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _questionTypes == value;

    return InkWell(
      onTap:
          _isGenerating
              ? null
              : () {
                setState(() {
                  _questionTypes = value;
                });
              },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          border: Border.all(color: colorScheme.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
