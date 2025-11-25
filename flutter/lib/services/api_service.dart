// lib/services/api_service.dart (통합본)
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/chat_models.dart';
import '../models/learning_models.dart';
import 'auth.dart'; // 추가

class ApiService {
  static final String baseUrl = AppConfig.baseUrl;

  // ========== 기본 메서드 (인증 헤더 적용) ==========
  
  // 채팅방 목록 조회
  static Future<List<ChatRoom>> getChatRooms() async {
    try {
      final headers = await AuthService.getAuthHeaders(); // 인증 헤더
      final response = await http
          .get(Uri.parse('$baseUrl/api/rooms'), headers: headers)
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => ChatRoom.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load chat rooms: ${response.statusCode}');
      }
    } catch (e) {
      print('API Error (getChatRooms): $e');
      throw e;
    }
  }

  // 채팅방 생성
  static Future<ChatRoom> createChatRoom(String title) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/rooms'),
            headers: headers,
            body: json.encode({'title': title}),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ChatRoom.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create chat room: ${response.statusCode}');
      }
    } catch (e) {
      print('API Error (createChatRoom): $e');
      throw e;
    }
  }

  // 메시지 조회
  static Future<List<Message>> getMessages(String roomId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/rooms/$roomId/messages'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      print('API Error (getMessages): $e');
      throw e;
    }
  }

  // 채팅방 삭제
  static Future<bool> deleteChatRoom(String roomId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl/api/rooms/$roomId'), headers: headers)
          .timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('API Error (deleteChatRoom): $e');
      return false;
    }
  }

  // ========== 추가 메서드 (내 것에서 가져옴) ==========
  
  // 여러 채팅방 한 번에 삭제 (추가)
  static Future<bool> deleteMultipleChatRooms(List<String> roomIds) async {
    try {
      final headers = await AuthService.getAuthHeaders(); // 인증 헤더 추가
      final response = await http.post(
        Uri.parse('$baseUrl/api/rooms/delete-multiple'),
        headers: headers,
        body: json.encode({'room_ids': roomIds}),
      ).timeout(Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      print('API Error (deleteMultipleChatRooms): $e');
      return false;
    }
  }

  // 메시지 저장 API (추가)
  static Future<void> saveMessage(String roomId, String content, String phase) async {
    try {
      final headers = await AuthService.getAuthHeaders(); // 인증 헤더 추가
      await http.post(
        Uri.parse('$baseUrl/api/rooms/$roomId/messages'),
        headers: headers,
        body: json.encode({
          'content': content,
          'role': 'user',
          'phase': phase,
        }),
      ).timeout(Duration(seconds: 10));
    } catch (e) {
      print('API Error (saveMessage): $e');
      throw e;
    }
  }

  // PDF 업로드 (추가)
  static Future<bool> uploadPdf(String roomId, String filePath) async {
    try {
      final token = await AuthService.getToken(); // 토큰 가져오기
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/rooms/$roomId/upload-pdf'),
      );
      
      // 인증 헤더 추가
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // 파일 추가
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );
      
      var response = await request.send().timeout(Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        print('✅ PDF 업로드 성공');
        return true;
      } else {
        var responseBody = await response.stream.bytesToString();
        print('❌ PDF 업로드 실패: $responseBody');
        return false;
      }
    } catch (e) {
      print('API Error (uploadPdf): $e');
      return false;
    }
  }

  // 현재 학습 단계 조회
  static Future<PhaseInfo> getLearningPhase(String roomId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/learning/phase/$roomId'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return PhaseInfo.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to get learning phase');
      }
    } catch (e) {
      print('API Error (getLearningPhase): $e');
      throw e;
    }
  }

  // 학습 단계 전환
  static Future<Map<String, dynamic>> transitionPhase(
    String roomId,
    String? userChoice,
  ) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/learning/transition'),
            headers: headers,
            body: json.encode({'room_id': roomId, 'user_choice': userChoice}),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to transition phase');
      }
    } catch (e) {
      print('API Error (transitionPhase): $e');
      throw e;
    }
  }

  // 키워드 추출
  static Future<String> extractKeyword(String text) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/extract-keyword'),
            headers: headers,
            body: json.encode({'text': text}),
          )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['extracted_keyword'] ?? text;
      } else {
        print('Keyword extraction failed, using original text');
        return text;
      }
    } catch (e) {
      print('API Error (extractKeyword): $e');
      return text; // 실패 시 원본 텍스트 반환
    }
  }

  // 학습 초기화 (PDF 뷰어에서 학습 시작 시)
  static Future<void> initializeLearning(String roomId, String concept) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/rooms/$roomId/initialize-learning'),
            headers: headers,
            body: json.encode({'concept': concept}),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to initialize learning');
      }
    } catch (e) {
      print('API Error (initializeLearning): $e');
      throw e;
    }
  }

  // ========== PDF 및 폴더 관리 API ==========
  
  // 폴더 목록 조회
  static Future<List<Folder>> getFolders() async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/folders/list'), headers: headers)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => Folder.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load folders');
      }
    } catch (e) {
      print('API Error (getFolders): $e');
      throw e;
    }
  }

  // 폴더 생성
  static Future<Folder> createFolder(String name) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/folders/create'),
            headers: headers,
            body: json.encode({'name': name}),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return Folder.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create folder');
      }
    } catch (e) {
      print('API Error (createFolder): $e');
      throw e;
    }
  }

  // 폴더 삭제
  static Future<bool> deleteFolder(String folderId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/folders/$folderId'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('API Error (deleteFolder): $e');
      return false;
    }
  }

  // 폴더 이름 변경
  static Future<Folder> renameFolder(String folderId, String newName) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/folders/$folderId'),
            headers: headers,
            body: json.encode({'name': newName}),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return Folder.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to rename folder');
      }
    } catch (e) {
      print('API Error (renameFolder): $e');
      throw e;
    }
  }

  // PDF 목록 조회 (폴더별 필터링)
  static Future<List<PDFFile>> getPDFList({String? folderId}) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      String url = '$baseUrl/api/pdf/list';
      if (folderId != null) {
        url += '?folder_id=$folderId';
      }
      
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => PDFFile.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load PDF list');
      }
    } catch (e) {
      print('API Error (getPDFList): $e');
      throw e;
    }
  }

  // PDF 업로드 (새 API)
  static Future<PDFFile?> uploadPDFFile(String filePath, {String? folderId}) async {
    try {
      final token = await AuthService.getToken();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/pdf/upload'),
      );
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // 파일 추가
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );
      
      // 폴더 ID 추가 (선택)
      if (folderId != null) {
        request.fields['folder_id'] = folderId;
      }
      
      var response = await request.send().timeout(Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        print('✅ PDF 업로드 성공');
        return PDFFile.fromJson(json.decode(responseBody));
      } else {
        var responseBody = await response.stream.bytesToString();
        print('❌ PDF 업로드 실패: $responseBody');
        return null;
      }
    } catch (e) {
      print('API Error (uploadPDFFile): $e');
      return null;
    }
  }

  // PDF 사용 중인 채팅방 수 확인
  static Future<Map<String, dynamic>?> checkPDFUsage(String pdfId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/pdf/$pdfId/usage'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print('API Error (checkPDFUsage): $e');
      return null;
    }
  }

  // PDF 삭제
  static Future<Map<String, dynamic>?> deletePDF(String pdfId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/pdf/$pdfId'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print('API Error (deletePDF): $e');
      return null;
    }
  }

  // PDF 이동 (다른 폴더로)
  static Future<PDFFile?> movePDF(String pdfId, String? targetFolderId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/pdf/$pdfId/move'),
            headers: headers,
            body: json.encode({'folder_id': targetFolderId}),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return PDFFile.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to move PDF');
      }
    } catch (e) {
      print('API Error (movePDF): $e');
      return null;
    }
  }

  // 채팅방에 PDF 연결
  static Future<bool> linkPDFToRoom(String roomId, String pdfId) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/rooms/$roomId/link-pdf?pdf_id=$pdfId'),
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('API Error (linkPDFToRoom): $e');
      return false;
    }
  }
}