import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class GoogleDriveService {
  static const String _driveApiBase = 'https://www.googleapis.com/drive/v3';
  static const String _uploadApiBase = 'https://www.googleapis.com/upload/drive/v3';
  
  final AuthService _authService;

  GoogleDriveService(this._authService);

  /// Get auth headers for API calls
  Future<Map<String, String>> _getHeaders() async {
    final headers = await _authService.getGoogleAuthHeaders();
    if (headers == null) {
      throw Exception('Not signed in with Google. Please sign in first.');
    }
    return headers;
  }

  /// Create a folder in Google Drive
  Future<Map<String, dynamic>> createFolder(
    String name, {
    String? parentId,
  }) async {
    final headers = await _getHeaders();
    
    final metadata = {
      'name': name,
      'mimeType': 'application/vnd.google-apps.folder',
      if (parentId != null) 'parents': [parentId],
    };

    final response = await http.post(
      Uri.parse('$_driveApiBase/files'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(metadata),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create folder: ${response.body}');
    }

    return jsonDecode(response.body);
  }

  /// Make a folder/file public (anyone with link can access)
  Future<void> makePublic(String fileId, {String role = 'writer'}) async {
    final headers = await _getHeaders();
    
    final permission = {
      'type': 'anyone',
      'role': role,
    };

    final response = await http.post(
      Uri.parse('$_driveApiBase/files/$fileId/permissions'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(permission),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to set permissions: ${response.body}');
    }
  }

  /// Get file/folder web view link
  Future<String?> getWebViewLink(String fileId) async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$_driveApiBase/files/$fileId?fields=webViewLink'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);
    return data['webViewLink'];
  }

  /// Create a public event folder with sub-folder
  Future<EventFolderResult> createEventFolder(
    String eventName,
    String initialFolderName,
  ) async {
    // Create root event folder
    final rootFolder = await createFolder(eventName);
    final rootFolderId = rootFolder['id'];
    
    // Make root folder public (anyone can write)
    await makePublic(rootFolderId, role: 'writer');
    
    // Get the web view link
    final webViewLink = await getWebViewLink(rootFolderId);
    
    // Create initial sub-folder
    final subFolder = await createFolder(
      initialFolderName,
      parentId: rootFolderId,
    );
    
    return EventFolderResult(
      rootFolderId: rootFolderId,
      rootFolderLink: webViewLink,
      subFolderId: subFolder['id'],
      subFolderName: initialFolderName,
    );
  }

  /// Create a sub-folder within an event folder
  Future<String> createSubFolder(String parentId, String name) async {
    final folder = await createFolder(name, parentId: parentId);
    return folder['id'];
  }

  /// Upload a file to Google Drive
  Future<UploadResult> uploadFile(
    File file,
    String folderId,
    String fileName, {
    void Function(int, int)? onProgress,
  }) async {
    final headers = await _getHeaders();
    
    // Get file bytes
    final bytes = await file.readAsBytes();
    final fileSize = bytes.length;
    
    // Determine mime type
    final mimeType = _getMimeType(fileName);
    
    // Create metadata
    final metadata = {
      'name': fileName,
      'parents': [folderId],
    };

    // Create multipart request
    final boundary = '-------${DateTime.now().millisecondsSinceEpoch}';
    
    final body = StringBuffer();
    body.writeln('--$boundary');
    body.writeln('Content-Type: application/json; charset=UTF-8');
    body.writeln();
    body.writeln(jsonEncode(metadata));
    body.writeln('--$boundary');
    body.writeln('Content-Type: $mimeType');
    body.writeln('Content-Transfer-Encoding: base64');
    body.writeln();
    body.writeln(base64Encode(bytes));
    body.writeln('--$boundary--');

    final response = await http.post(
      Uri.parse('$_uploadApiBase/files?uploadType=multipart'),
      headers: {
        ...headers,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body.toString(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to upload file: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final fileId = data['id'];
    
    // Make the file viewable
    await makePublic(fileId, role: 'reader');
    
    // Get web link
    final webLink = await getWebViewLink(fileId);

    return UploadResult(
      fileId: fileId,
      webLink: webLink,
      fileName: fileName,
      fileSize: fileSize,
    );
  }

  /// Delete a file from Google Drive
  Future<void> deleteFile(String fileId) async {
    final headers = await _getHeaders();
    
    final response = await http.delete(
      Uri.parse('$_driveApiBase/files/$fileId'),
      headers: headers,
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete file: ${response.body}');
    }
  }

  /// List files in a folder
  Future<List<Map<String, dynamic>>> listFiles(String folderId) async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse(
        "$_driveApiBase/files?q='$folderId'+in+parents&fields=files(id,name,mimeType,webViewLink,thumbnailLink,size,createdTime)",
      ),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to list files: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['files'] ?? []);
  }

  /// Get MIME type from file extension
  String _getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Result of creating an event folder
class EventFolderResult {
  final String rootFolderId;
  final String? rootFolderLink;
  final String subFolderId;
  final String subFolderName;

  EventFolderResult({
    required this.rootFolderId,
    this.rootFolderLink,
    required this.subFolderId,
    required this.subFolderName,
  });
}

/// Result of uploading a file
class UploadResult {
  final String fileId;
  final String? webLink;
  final String fileName;
  final int fileSize;

  UploadResult({
    required this.fileId,
    this.webLink,
    required this.fileName,
    required this.fileSize,
  });
}
