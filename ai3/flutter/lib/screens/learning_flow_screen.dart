// lib/screens/learning_flow_screen.dart (동적 학습 화면)
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/learning_models.dart';

class LearningFlowScreen extends StatefulWidget {
  final String concept;
  final String roomId;
  final String initialPhase;

  const LearningFlowScreen({
    Key? key,
    required this.concept,
    required this.roomId,
    required this.initialPhase,
  }) : super(key: key);

  @override
  _LearningFlowScreenState createState() => _LearningFlowScreenState();
}

class _LearningFlowScreenState extends State<LearningFlowScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();

  String _currentPhase = '';
  String _questionText = '';
  bool _showButtons = true;
  bool _showInput = false;
  bool _isLoading = false;

  // 애니메이션
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // 메시지 저장
  String _userExplanation = '';
  String _userReflection = '';

  @override
  void initState() {
    super.initState();
    _currentPhase = widget.initialPhase;
    _updateQuestionText();

    // 애니메이션 초기화
    _animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  void _updateQuestionText() {
    setState(() {
      switch (_currentPhase) {
        case LearningPhase.KNOWLEDGE_CHECK:
          _questionText = '이 개념에 대해\n얼마나 알고 계신가요?';
          _showButtons = true;
          _showInput = false;
          break;
        case LearningPhase.FIRST_EXPLANATION:
          _questionText = '알고 있는 만큼\n자유롭게 설명해주세요';
          _showButtons = false;
          _showInput = true;
          break;
        case LearningPhase.SELF_REFLECTION_1:
          _questionText = '설명하면서 막혔던 부분이나\n확신이 없었던 부분을 말해주세요';
          _showButtons = false;
          _showInput = true;
          break;
        default:
          _questionText = '';
      }
    });
  }

  // 버튼 클릭 처리
  Future<void> _handleKnowledgeChoice(String choice) async {
    setState(() => _isLoading = true);

    try {
      // API로 단계 전환
      await ApiService.transitionPhase(widget.roomId, choice);

      // 애니메이션과 함께 단계 전환
      await _animationController.reverse();

      if (choice == 'knows') {
        setState(() {
          _currentPhase = LearningPhase.FIRST_EXPLANATION;
          _updateQuestionText();
        });
        await _animationController.forward();
      } else {
        // "모른다" 선택 시 AI 설명 화면으로 바로 이동
        Navigator.pushReplacementNamed(
          context,
          '/ai_explanation',
          arguments: {'roomId': widget.roomId, 'concept': widget.concept},
        );
        return;
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 입력 전송 처리
  Future<void> _handleSubmit() async {
    if (_inputController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final message = _inputController.text.trim();

      if (_currentPhase == LearningPhase.FIRST_EXPLANATION) {
        // 첫 번째 설명 저장
        _userExplanation = message;

        // SELF_REFLECTION_1 단계로 전환
        await _animationController.reverse();
        setState(() {
          _currentPhase = LearningPhase.SELF_REFLECTION_1;
          _updateQuestionText();
          _inputController.clear();
        });
        await _animationController.forward();
      } else if (_currentPhase == LearningPhase.SELF_REFLECTION_1) {
        // 성찰 저장
        _userReflection = message;

        // AI 설명 화면으로 이동
        Navigator.pushReplacementNamed(
          context,
          '/ai_explanation',
          arguments: {
            'roomId': widget.roomId,
            'concept': widget.concept,
            'explanation': _userExplanation,
            'reflection': _userReflection,
          },
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('파인만 학습'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 아이콘
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _showButtons ? Icons.psychology : Icons.edit_note,
                              size: 60,
                              color: Colors.blue.shade700,
                            ),
                          ),

                          SizedBox(height: 40),

                          // 개념 표시
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.concept,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),

                          SizedBox(height: 30),

                          // 질문 텍스트
                          Text(
                            _questionText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                              height: 1.4,
                            ),
                          ),

                          SizedBox(height: 60),

                          // 버튼 또는 입력창
                          if (_showButtons) ..._buildButtons(),
                          if (_showInput) _buildInputArea(),

                          if (_isLoading)
                            Padding(
                              padding: EdgeInsets.only(top: 20),
                              child: CircularProgressIndicator(),
                            ),
                        ],
                      ),
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

  List<Widget> _buildButtons() {
    return [
      // 알고 있다 버튼
      SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _handleKnowledgeChoice('knows'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
          onPressed:
              _isLoading ? null : () => _handleKnowledgeChoice('doesnt_know'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade400,
            foregroundColor: Colors.white,
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),

      SizedBox(height: 40),

      // 안내 텍스트
      Text(
        '솔직하게 답변해주세요.\n모르는 것은 부끄러운 게 아니에요!',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade600,
          height: 1.5,
        ),
      ),
    ];
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            maxLines: 5,
            decoration: InputDecoration(
              hintText: '여기에 입력하세요...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send),
                  SizedBox(width: 8),
                  Text(
                    '전송',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _inputController.dispose();
    super.dispose();
  }
}
