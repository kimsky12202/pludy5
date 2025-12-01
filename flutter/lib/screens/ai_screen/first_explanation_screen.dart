// lib/screens/first_explanation_screen.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/speech_service.dart';
import 'dart:async';


class FirstExplanationScreen extends StatefulWidget {
  final String concept;
  final String roomId;

  const FirstExplanationScreen({
    Key? key,
    required this.concept,
    required this.roomId,
  }) : super(key: key);

  @override
  _FirstExplanationScreenState createState() => _FirstExplanationScreenState();
}

class _FirstExplanationScreenState extends State<FirstExplanationScreen>
    with SingleTickerProviderStateMixin {

  final TextEditingController _inputController = TextEditingController();
  final SpeechService _speechService = SpeechService();
  bool _isLoading = false;
  bool _isRecording = false;
  bool _isExpanded = false; // 키워드 텍스트 펼침 상태
  String _recognizedText = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Timer? _restartTimer;


  // 음성 녹음 토글
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // 녹음 중지
      _restartTimer?.cancel();
      print('🎤 녹음 중지. 인식된 텍스트: "$_recognizedText"');
      await _speechService.stopListening();
      setState(() => _isRecording = false);

      if (_recognizedText.isEmpty) {
        print('⚠️ 인식된 텍스트가 없습니다');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음성이 인식되지 않았습니다.')),
        );
        return;
      }

      print('📤 제출 시작: $_recognizedText');
      await _submitWithText(_recognizedText);
    } else {
      // 녹음 시작
      print('🎤 녹음 시작');
      bool initialized = await _speechService.initialize();
      if (!initialized) {
        print('❌ 음성 인식 초기화 실패');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('마이크 권한이 필요합니다')),
        );
        return;
      }

      setState(() {
        _isRecording = true;
        _recognizedText = '';
      });

      await _speechService.startListening(
        onResult: (text) {
          print('🎤 인식 중: $text');
          setState(() {
            _recognizedText = text;
          });
        },
      );

      // 1초마다 체크, 녹음 중이 아니면 바로 재시작
      _restartTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
        if (!_isRecording) {
          timer.cancel();
          return;
        }

        if (!_speechService.isListening) {
          print('⏰ 타이머: 녹음 중지 감지 → 재시작');
          await _speechService.restart();
        } else {
          print('⏰ 타이머: 녹음 중 → 대기');
        }
      });
    }
  }


  // 텍스트로 제출
  Future<void> _submitWithText(String text) async {
    if (text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ApiService.saveMessage(widget.roomId, text, 'first_explanation');
      await ApiService.transitionPhase(widget.roomId, null);

      Navigator.pushReplacementNamed(
        context,
        '/first_reflection',
        arguments: {
          'roomId': widget.roomId,
          'concept': widget.concept,
          'explanation': text,
        },
      );
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    await _submitWithText(_inputController.text.trim());
  }




  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('파인만 학습'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView( // 스크롤 가능하도록 추가
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 40), // 상단 여백

                      // 아이콘
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_note,
                          size: 60,
                          color: colorScheme.primary,
                        ),
                      ),

                      SizedBox(height: 40),

                      // 개념 표시 (펼치기/접기 기능)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorScheme.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                widget.concept,
                                textAlign: TextAlign.center,
                                maxLines: _isExpanded ? null : 1,
                                overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 19, // 요구사항: 크기 19
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              if (widget.concept.length > 20) // 긴 텍스트인 경우에만 표시
                                Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Icon(
                                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    size: 20,
                                    color: colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 30),

                      // 질문
                      Text(
                        '알고 있는 만큼\n자유롭게 설명해주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17, // 22 → 17 (5 줄임)
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withOpacity(0.7),
                          height: 1.4,
                        ),
                      ),

                      SizedBox(height: 60),

                      // 입력 영역
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _inputController,
                              maxLines: 3, // 5 → 3 (높이 줄임)
                              decoration: InputDecoration(
                                hintText: '여기에 입력하세요...',
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                // 마이크 버튼
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _toggleRecording,
                                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                                    label: Text(_isRecording ? '중지' : '음성'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isRecording
                                          ? Colors.red // 녹음 중: 빨간색 유지
                                          : colorScheme.secondary, // 녹음 대기: Black&White 적용
                                      foregroundColor: _isRecording
                                          ? Colors.white
                                          : colorScheme.onSecondary,
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                // 텍스트 전송 버튼
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _handleSubmit,
                                    icon: Icon(Icons.send),
                                    label: Text('전송'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (_isLoading)
                        Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: CircularProgressIndicator(),
                        ),

                      SizedBox(height: 40), // 하단 여백
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    _animationController.dispose();
    _inputController.dispose();
    _speechService.dispose();
    super.dispose();
  }
}
