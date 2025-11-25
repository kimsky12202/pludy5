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
        canShowScrollHead: true,
        canShowScrollStatus: true,
        pageLayoutMode: PdfPageLayoutMode.continuous,
      ),
    );
  }
}
