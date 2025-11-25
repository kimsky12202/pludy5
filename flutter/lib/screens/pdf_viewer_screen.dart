// lib/screens/fileview_screens/pdf_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
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
  String? _selectedText;

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  // 텍스트 선택 핸들러
  void _handleTextSelection(PdfTextSelectionChangedDetails details) {
    print('📝 텍스트 선택 이벤트: ${details.selectedText}');
    setState(() {
      _selectedText = details.selectedText;
    });
  }

  // 텍스트 선택 메뉴
  void _showTextSelectionMenu() {
    if (_selectedText == null || _selectedText!.isEmpty) return;

    // 선택된 텍스트를 임시 저장
    final selectedTextCopy = _selectedText!;

    // Syncfusion 기본 메뉴를 닫기 위해 텍스트 선택 해제
    _pdfViewerController.clearSelection();

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
                selectedTextCopy,
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
              _startLearningWithText(selectedTextCopy);
            },
            child: Text('시작'),
          ),
        ],
      ),
    );
  }

  // 학습 시작
  void _startLearningWithText(String selectedText) async {
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

      print('📝 선택된 텍스트: $selectedText');

      // 1단계: 채팅방 생성 (원본 텍스트로 제목 생성)
      final displayText = selectedText.length > 20
          ? '${selectedText.substring(0, 20)}...'
          : selectedText;
      final room = await ApiService.createChatRoom('$displayText 학습');

      // 2단계: PDF 연결
      await ApiService.linkPDFToRoom(room.id, widget.pdfFile.id);

      // 3단계: 백엔드 학습 초기화 (원본 텍스트 그대로 전달)
      // 백엔드에서 키워드 추출은 내부적으로 처리
      await ApiService.initializeLearning(room.id, selectedText);

      Navigator.pop(context);

      // 4단계: 학습 화면으로 이동 (원본 텍스트 사용)
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/knowledge_check',
          (route) => false,
          arguments: {
            'roomId': room.id,
            'concept': selectedText,  // 원본 텍스트 그대로 사용
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

  @override
  Widget build(BuildContext context) {
    final pdfUrl = '${AppConfig.baseUrl}/${widget.pdfFile.filePath}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pdfFile.originalFilename, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedText != null && _selectedText!.isNotEmpty)
            IconButton(
              icon: Icon(Icons.school),
              onPressed: _showTextSelectionMenu,
              tooltip: 'AI 학습',
            ),
        ],
      ),
      body: SfPdfViewer.network(
        pdfUrl,
        controller: _pdfViewerController,
        onTextSelectionChanged: _handleTextSelection,
        enableTextSelection: true,
        interactionMode: PdfInteractionMode.selection,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        pageLayoutMode: PdfPageLayoutMode.continuous,
      ),
    );
  }
}
