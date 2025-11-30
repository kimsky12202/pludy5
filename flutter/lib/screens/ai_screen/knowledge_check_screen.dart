// lib/screens/knowledge_check_screen.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class KnowledgeCheckScreen extends StatefulWidget {
  final String concept;
  final String roomId;

  const KnowledgeCheckScreen({
    Key? key,
    required this.concept,
    required this.roomId,
  }) : super(key: key);

  @override
  _KnowledgeCheckScreenState createState() => _KnowledgeCheckScreenState();
}

class _KnowledgeCheckScreenState extends State<KnowledgeCheckScreen>
    with SingleTickerProviderStateMixin {

  bool _isLoading = false;
  bool _isExpanded = false; // 키워드 텍스트 펼침 상태
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

  Future<void> _handleChoice(String choice) async {
    setState(() => _isLoading = true);

    try {
      await ApiService.transitionPhase(widget.roomId, choice);

      if (choice == 'knows') {
        // "알고 있어요" → 첫 번째 설명 화면으로
        Navigator.pushReplacementNamed(
          context,
          '/first_explanation',
          arguments: {
            'roomId': widget.roomId,
            'concept': widget.concept,
          },
        );
      } else {
        // "모른다" → AI 설명 화면으로
        Navigator.pushReplacementNamed(
          context,
          '/ai_explanation',
          arguments: {
            'roomId': widget.roomId,
            'concept': widget.concept,
          },
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async => false,  // 뒤로가기 막기
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
                          Icons.psychology,
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
                                  fontSize: 19, // 24 → 19 (5 줄임)
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
                        '이 개념에 대해\n얼마나 알고 계신가요?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17, // 22 → 17 (5 줄임)
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withOpacity(0.7),
                          height: 1.4,
                        ),
                      ),

                      SizedBox(height: 60),

                      // 알고 있다 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _handleChoice('knows'),
                          style: ElevatedButton.styleFrom(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, size: 28),
                              SizedBox(width: 12),
                              Text(
                                '알고 있어요',
                                style: TextStyle(
                                  fontSize: 15, // 20 → 15 (5 줄임)
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // 모른다 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _handleChoice('doesnt_know'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.secondary,
                            foregroundColor: colorScheme.onSecondary,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.help_outline, size: 28),
                              SizedBox(width: 12),
                              Text(
                                '잘 모르겠어요',
                                style: TextStyle(
                                  fontSize: 15, // 20 → 15 (5 줄임)
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 40),

                      // 안내 텍스트
                      Text(
                        '솔직하게 답변해주세요.\n모르는 것은 부끄러운 게 아닙니다!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withOpacity(0.5),
                          height: 1.5,
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
    _animationController.dispose();
    super.dispose();
  }
}
