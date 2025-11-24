// lib/screens/fileview_screens/pdf_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:signature/signature.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/learning_models.dart';
import '../../services/api_service.dart';
import '../../config/app_config.dart';

class PDFViewerScreen extends StatefulWidget {
  final PDFFile pdfFile;

  const PDFViewerScreen({
    Key? key,
    required this.pdfFile,
  }) : super(key: key);

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  late SignatureController _signatureController;
  
  String? _selectedText;
  bool _isDrawingMode = false;
  bool _isHighlighterMode = false;
  int _currentPage = 1;
  
  // 펜 설정
  Color _penColor = Colors.red;
  double _penWidth = 3.0;
  
  // 형광펜 설정
  Color _highlighterColor = Colors.yellow;
  double _highlighterWidth = 20.0;

  @override
  void initState() {
    super.initState();
    _initSignatureController();
    _loadAnnotations();
  }

  // SignatureController 초기화
  void _initSignatureController() {
    _signatureController = SignatureController(
      penStrokeWidth: _penWidth,
      penColor: _penColor,
      exportBackgroundColor: Colors.transparent,
    );
  }

  // SignatureController 재생성 (색상/두께 변경 시)
  void _recreateSignatureController({Color? color, double? width}) {
    // 기존 그림 저장
    final oldPoints = _signatureController.points;
    
    // 새 컨트롤러 생성
    _signatureController.dispose();
    _signatureController = SignatureController(
      penStrokeWidth: width ?? _penWidth,
      penColor: color ?? _penColor,
      exportBackgroundColor: Colors.transparent,
    );
    
    // 기존 그림 복원 (가능하면)
    // points는 직접 설정 불가능하므로 새로 그려야 함
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  // 주석 저장
  Future<void> _saveAnnotations() async {
    if (_signatureController.isEmpty) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'annotations_${widget.pdfFile.id}_page_$_currentPage';
      
      final image = await _signatureController.toPngBytes();
      if (image != null) {
        final base64Image = base64Encode(image);
        await prefs.setString(key, base64Image);
        print('✅ 주석 저장 완료');
      }
    } catch (e) {
      print('❌ 주석 저장 오류: $e');
    }
  }

  // 주석 불러오기
  Future<void> _loadAnnotations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'annotations_${widget.pdfFile.id}_page_$_currentPage';
      final base64Image = prefs.getString(key);
      
      if (base64Image != null) {
        print('📝 주석 데이터 발견');
      }
    } catch (e) {
      print('❌ 주석 로드 오류: $e');
    }
  }

  // 주석 초기화
  void _clearAnnotations() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('주석 지우기'),
        content: Text('현재 페이지의 모든 주석을 지우시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              _signatureController.clear();
              
              final prefs = await SharedPreferences.getInstance();
              final key = 'annotations_${widget.pdfFile.id}_page_$_currentPage';
              await prefs.remove(key);
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('주석이 삭제되었습니다')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 텍스트 선택 핸들러
  void _handleTextSelection(PdfTextSelectionChangedDetails details) {
    if (_isDrawingMode) return;

    setState(() {
      _selectedText = details.selectedText;
    });
  }

  // 텍스트 선택 메뉴
  void _showTextSelectionMenu() {
    if (_selectedText == null || _selectedText!.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('AI 학습'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('선택한 텍스트로 학습을 시작하시겠습니까?'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _selectedText!,
                style: TextStyle(fontSize: 14),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startLearningWithText(_selectedText!);
            },
            child: Text('시작'),
          ),
        ],
      ),
    );
  }

  // 학습 시작
  void _startLearningWithText(String concept) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('학습 준비 중...'),
                ],
              ),
            ),
          ),
        ),
      );

      final room = await ApiService.createChatRoom('$concept 학습');
      await ApiService.linkPDFToRoom(room.id, widget.pdfFile.id);
      
      Navigator.pop(context);
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/knowledge_check',
          (route) => false,
          arguments: {
            'roomId': room.id,
            'concept': concept,
          },
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('학습 시작 실패: $e')),
      );
    }
  }

  // 펜 설정 다이얼로그
  void _showPenSettings() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('펜 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('색상', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _colorButton(Colors.red, setDialogState),
                  _colorButton(Colors.blue, setDialogState),
                  _colorButton(Colors.green, setDialogState),
                  _colorButton(Colors.black, setDialogState),
                  _colorButton(Colors.orange, setDialogState),
                  _colorButton(Colors.purple, setDialogState),
                ],
              ),
              SizedBox(height: 16),
              Text('두께: ${_penWidth.toInt()}', style: TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _penWidth,
                min: 1,
                max: 10,
                divisions: 9,
                label: _penWidth.toInt().toString(),
                onChanged: (value) {
                  setDialogState(() {
                    _penWidth = value;
                  });
                  setState(() {
                    _penWidth = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // 변경사항 적용을 위해 컨트롤러 재생성
                _recreateSignatureController(color: _penColor, width: _penWidth);
                Navigator.pop(context);
              },
              child: Text('완료'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorButton(Color color, StateSetter setDialogState) {
    final isSelected = _penColor == color;
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          _penColor = color;
        });
        setState(() {
          _penColor = color;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected ? Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pdfUrl = '${AppConfig.baseUrl}/${widget.pdfFile.filePath}';

    return WillPopScope(
      onWillPop: () async {
        if (_isDrawingMode) {
          await _saveAnnotations();
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.pdfFile.originalFilename, overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            if (_selectedText != null && _selectedText!.isNotEmpty && !_isDrawingMode)
              IconButton(
                icon: Icon(Icons.school),
                onPressed: _showTextSelectionMenu,
                tooltip: 'AI 학습',
              ),
            if (_isDrawingMode)
              IconButton(
                icon: Icon(Icons.settings),
                onPressed: _showPenSettings,
                tooltip: '펜 설정',
              ),
          ],
        ),
        body: Column(
          children: [
            if (_isDrawingMode)
              Container(
                color: _isHighlighterMode ? Colors.yellow.shade100 : Colors.orange.shade100,
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _isHighlighterMode ? Icons.highlight : Icons.edit,
                      color: _isHighlighterMode ? Colors.yellow.shade900 : Colors.orange.shade900,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isHighlighterMode 
                            ? '형광펜 모드 - PDF에 하이라이트하세요'
                            : '펜 모드 - PDF에 자유롭게 그리세요',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isHighlighterMode ? Colors.yellow.shade900 : Colors.orange.shade900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _saveAnnotations();
                        setState(() => _isDrawingMode = false);
                      },
                      child: Text('완료'),
                    ),
                  ],
                ),
              ),
            
            Expanded(
              child: Stack(
                children: [
                  SfPdfViewer.network(
                    pdfUrl,
                    controller: _pdfViewerController,
                    onTextSelectionChanged: _handleTextSelection,
                    enableTextSelection: !_isDrawingMode,
                    canShowScrollHead: true,
                    canShowScrollStatus: true,
                    pageLayoutMode: PdfPageLayoutMode.continuous,
                    onPageChanged: (PdfPageChangedDetails details) {
                      setState(() {
                        _currentPage = details.newPageNumber;
                      });
                    },
                  ),
                  
                  if (_isDrawingMode)
                    Positioned.fill(
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        
        bottomNavigationBar: BottomAppBar(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _toolButton(
                  icon: Icons.edit,
                  label: '펜',
                  isActive: _isDrawingMode && !_isHighlighterMode,
                  color: Colors.red,
                  onPressed: () {
                    setState(() {
                      if (!_isDrawingMode || _isHighlighterMode) {
                        _isDrawingMode = true;
                        _isHighlighterMode = false;
                        _recreateSignatureController(color: _penColor, width: _penWidth);
                      }
                    });
                  },
                ),
                
                _toolButton(
                  icon: Icons.highlight,
                  label: '형광펜',
                  isActive: _isDrawingMode && _isHighlighterMode,
                  color: Colors.yellow.shade700,
                  onPressed: () {
                    setState(() {
                      if (!_isDrawingMode || !_isHighlighterMode) {
                        _isDrawingMode = true;
                        _isHighlighterMode = true;
                        _recreateSignatureController(
                          color: _highlighterColor.withOpacity(0.5),
                          width: _highlighterWidth,
                        );
                      }
                    });
                  },
                ),
                
                _toolButton(
                  icon: Icons.cleaning_services,
                  label: '지우기',
                  onPressed: _clearAnnotations,
                ),
                
                _toolButton(
                  icon: Icons.school,
                  label: '학습',
                  color: Colors.blue,
                  onPressed: () {
                    final controller = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('학습할 개념 입력'),
                        content: TextField(
                          controller: controller,
                          decoration: InputDecoration(hintText: '예: 미적분학'),
                          autofocus: true,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('취소'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (controller.text.trim().isNotEmpty) {
                                Navigator.pop(context);
                                _startLearningWithText(controller.text.trim());
                              }
                            },
                            child: Text('학습 시작'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    Color? color,
    required VoidCallback onPressed,
  }) {
    final buttonColor = isActive ? (color ?? Colors.orange) : Colors.grey;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: Icon(icon, color: buttonColor), onPressed: onPressed),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: buttonColor,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}