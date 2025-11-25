// lib/screens/fileview_screens/fileview_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../models/learning_models.dart';
import 'pdf_viewer_screen.dart';

class FileViewScreen extends StatefulWidget {
  const FileViewScreen({super.key});

  @override
  FileViewScreenState createState() => FileViewScreenState();
}

class FileViewScreenState extends State<FileViewScreen> with WidgetsBindingObserver {
  List<Folder> _folders = [];
  List<PDFFile> _pdfs = [];
  String? _currentFolderId; // null이면 루트
  bool _isLoading = false;
  String _currentFolderName = '내 파일';

  // 삭제 모드 관련
  bool _isDeleteMode = false;
  Set<String> _selectedPdfIds = {};
  Set<String> _selectedFolderIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 포그라운드로 돌아올 때 새로고침
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  // 외부에서 호출 가능한 새로고침 메서드
  void refresh() {
    _loadData();
  }

  // 데이터 로드
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // 폴더 목록 로드
      final folders = await ApiService.getFolders();
      
      // PDF 목록 로드 (현재 폴더)
      final pdfs = await ApiService.getPDFList(folderId: _currentFolderId);
      
      setState(() {
        _folders = folders;
        _pdfs = pdfs;
        _isLoading = false;
      });
      
      print('✅ 데이터 로드 완료: ${folders.length}개 폴더, ${pdfs.length}개 PDF');
    } catch (e) {
      print('❌ 데이터 로드 오류: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터를 불러오는데 실패했습니다')),
        );
      }
    }
  }

  // 폴더 생성 다이얼로그
  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('새 폴더'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '폴더 이름',
            hintText: '예: 수학 강의',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('폴더 이름을 입력하세요')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              try {
                await ApiService.createFolder(controller.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('폴더가 생성되었습니다')),
                );
                _loadData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('폴더 생성 실패: $e')),
                );
              }
            },
            child: Text('생성'),
          ),
        ],
      ),
    );
  }

  // PDF 업로드
  Future<void> _uploadPDF() async {
    try {
      // 파일 선택
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      setState(() => _isLoading = true);

      final filePath = result.files.single.path!;
      
      // PDF 업로드
      final uploadedPDF = await ApiService.uploadPDFFile(
        filePath,
        folderId: _currentFolderId,
      );

      if (uploadedPDF != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF가 업로드되었습니다')),
        );
        _loadData();
      } else {
        throw Exception('업로드 실패');
      }
    } catch (e) {
      print('❌ PDF 업로드 오류: $e');
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 업로드 실패: $e')),
      );
    }
  }

  // 폴더 진입
  void _enterFolder(Folder folder) {
    setState(() {
      _currentFolderId = folder.id;
      _currentFolderName = folder.name;
    });
    _loadData();
  }

  // 루트로 돌아가기
  void _goToRoot() {
    setState(() {
      _currentFolderId = null;
      _currentFolderName = '내 파일';
    });
    _loadData();
  }

  // PDF 폴더 이동 다이얼로그
  Future<void> _showMovePDFDialog(PDFFile pdf) async {
    // 이동 가능한 폴더 목록 (루트 + 다른 폴더들)
    final availableFolders = [
      null, // 루트
      ..._folders.where((f) => f.id != pdf.folderId),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('폴더 이동'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${pdf.originalFilename}을(를) 이동할 폴더를 선택하세요'),
            SizedBox(height: 16),
            ...availableFolders.map((folder) => ListTile(
              leading: Icon(
                folder == null ? Icons.home : Icons.folder,
                color: folder == null ? Colors.blue : Colors.amber,
              ),
              title: Text(folder?.name ?? '루트 폴더'),
              onTap: () async {
                Navigator.pop(context);
                await _movePDF(pdf, folder?.id);
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
        ],
      ),
    );
  }

  // PDF 이동 실행
  Future<void> _movePDF(PDFFile pdf, String? targetFolderId) async {
    try {
      final result = await ApiService.movePDF(pdf.id, targetFolderId);
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일이 이동되었습니다')),
        );
        _loadData();
      } else {
        throw Exception('이동 실패');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 이동 실패: $e')),
      );
    }
  }

  // 선택 삭제 실행
  Future<void> _deleteSelected() async {
    if (_selectedPdfIds.isEmpty && _selectedFolderIds.isEmpty) return;

    final totalCount = _selectedPdfIds.length + _selectedFolderIds.length;

    // 확인 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('삭제 확인'),
        content: Text('선택한 $totalCount개 항목을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      int successCount = 0;

      // PDF 삭제
      for (final pdfId in _selectedPdfIds) {
        final result = await ApiService.deletePDF(pdfId);
        if (result != null) successCount++;
      }

      // 폴더 삭제
      for (final folderId in _selectedFolderIds) {
        final success = await ApiService.deleteFolder(folderId);
        if (success) successCount++;
      }

      setState(() {
        _selectedPdfIds.clear();
        _selectedFolderIds.clear();
        _isDeleteMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$successCount개 항목이 삭제되었습니다')),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_currentFolderId != null)
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: _goToRoot,
              ),
            Text(_currentFolderName),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_isDeleteMode)
            // 삭제 모드일 때
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _selectedPdfIds.isEmpty && _selectedFolderIds.isEmpty
                  ? null
                  : _deleteSelected,
              tooltip: '선택 삭제',
            )
          else
            // 일반 모드일 때
            ...[
              IconButton(
                icon: Icon(Icons.create_new_folder),
                onPressed: _showCreateFolderDialog,
                tooltip: '폴더 생성',
              ),
              IconButton(
                icon: Icon(Icons.upload_file),
                onPressed: _uploadPDF,
                tooltip: 'PDF 업로드',
              ),
            ],
          // 삭제 모드 토글 버튼
          IconButton(
            icon: Icon(_isDeleteMode ? Icons.close : Icons.delete_outline),
            onPressed: () {
              setState(() {
                _isDeleteMode = !_isDeleteMode;
                if (!_isDeleteMode) {
                  _selectedPdfIds.clear();
                  _selectedFolderIds.clear();
                }
              });
            },
            tooltip: _isDeleteMode ? '취소' : '삭제 모드',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _folders.isEmpty && _pdfs.isEmpty
                  ? _buildEmptyState()
                  : _buildFileList(),
            ),
    );
  }

  // 빈 상태 UI
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '파일이 없습니다',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            '상단의 버튼으로 폴더를 만들거나\nPDF를 업로드하세요',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // 파일 목록 UI
  Widget _buildFileList() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // 폴더 섹션 (루트에서만 표시)
        if (_currentFolderId == null && _folders.isNotEmpty) ...[
          Text(
            '폴더',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 12),
          ..._folders.map((folder) => _buildFolderCard(folder)),
          SizedBox(height: 24),
        ],
        
        // PDF 섹션
        if (_pdfs.isNotEmpty) ...[
          Text(
            'PDF 파일',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 12),
          ..._pdfs.map((pdf) => _buildPDFCard(pdf)),
        ],
      ],
    );
  }

  // 폴더 카드
  Widget _buildFolderCard(Folder folder) {
    final isSelected = _selectedFolderIds.contains(folder.id);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (_isDeleteMode) {
            setState(() {
              if (isSelected) {
                _selectedFolderIds.remove(folder.id);
              } else {
                _selectedFolderIds.add(folder.id);
              }
            });
          } else {
            _enterFolder(folder);
          }
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              if (_isDeleteMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedFolderIds.add(folder.id);
                      } else {
                        _selectedFolderIds.remove(folder.id);
                      }
                    });
                  },
                )
              else
                Icon(Icons.folder, size: 40, color: Colors.amber),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '생성일: ${_formatDate(folder.createdAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (!_isDeleteMode)
                Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // PDF 카드
  Widget _buildPDFCard(PDFFile pdf) {
    final isSelected = _selectedPdfIds.contains(pdf.id);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (_isDeleteMode) {
            setState(() {
              if (isSelected) {
                _selectedPdfIds.remove(pdf.id);
              } else {
                _selectedPdfIds.add(pdf.id);
              }
            });
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PDFViewerScreen(pdfFile: pdf),
              ),
            );
          }
        },
        onLongPress: () {
          if (!_isDeleteMode) {
            _showMovePDFDialog(pdf);
          }
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              if (_isDeleteMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedPdfIds.add(pdf.id);
                      } else {
                        _selectedPdfIds.remove(pdf.id);
                      }
                    });
                  },
                )
              else
                Icon(Icons.picture_as_pdf, size: 40, color: Colors.red),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pdf.originalFilename,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        if (pdf.pageCount != null) ...[
                          Icon(Icons.description, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            '${pdf.pageCount}페이지',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          SizedBox(width: 12),
                        ],
                        Icon(Icons.storage, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          pdf.fileSizeReadable,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      '업로드: ${_formatDate(pdf.uploadedAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 날짜 포맷
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}