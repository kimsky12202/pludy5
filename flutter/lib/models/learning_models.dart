// lib/models/learning_models.dart (새 파일)
class LearningPhase {
  static const String HOME = "home";
  static const String QUESTION_INPUT = "question_input";
  static const String KNOWLEDGE_CHECK = "knowledge_check";
  static const String FIRST_EXPLANATION = "first_explanation";
  static const String SELF_REFLECTION_1 = "self_reflection_1";
  static const String AI_EXPLANATION = "ai_explanation";
  static const String SECOND_EXPLANATION = "second_explanation";
  static const String SELF_REFLECTION_2 = "self_reflection_2";
  static const String EVALUATION = "evaluation";
}

class PhaseInfo {
  final String phase;
  final String instruction;
  final String title;
  final bool canGoBack;
  
  PhaseInfo({
    required this.phase,
    required this.instruction,
    required this.title,
    required this.canGoBack,
  });
  
  factory PhaseInfo.fromJson(Map<String, dynamic> json) {
    return PhaseInfo(
      phase: json['phase'],
      instruction: json['instruction'] ?? '',
      title: json['title'] ?? '',
      canGoBack: json['can_go_back'] ?? false,
    );
  }
}

// 폴더 모델
class Folder {
  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;

  Folder({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
  });

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

// PDF 파일 모델
class PDFFile {
  final String id;
  final String userId;
  final String? folderId;
  final String filename;
  final String originalFilename;
  final String filePath;
  final int fileSize;
  final int? pageCount;
  final DateTime uploadedAt;

  PDFFile({
    required this.id,
    required this.userId,
    this.folderId,
    required this.filename,
    required this.originalFilename,
    required this.filePath,
    required this.fileSize,
    this.pageCount,
    required this.uploadedAt,
  });

  factory PDFFile.fromJson(Map<String, dynamic> json) {
    return PDFFile(
      id: json['id'],
      userId: json['user_id'],
      folderId: json['folder_id'],
      filename: json['filename'],
      originalFilename: json['original_filename'],
      filePath: json['file_path'],
      fileSize: json['file_size'],
      pageCount: json['page_count'],
      uploadedAt: DateTime.parse(json['uploaded_at']),
    );
  }

  // 파일 크기를 읽기 쉬운 형식으로 변환
  String get fileSizeReadable {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}