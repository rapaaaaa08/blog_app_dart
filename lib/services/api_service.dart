import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/post.dart';
import '../models/user.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  // Base URL API, otomatis menyesuaikan target yang dipakai:
  //  - Android emulator : http://10.0.2.2:3006/api/v1  (10.0.2.2 = localhost PC)
  //  - Web / Windows    : http://localhost:3006/api/v1
  //  - HP fisik (WiFi)  : wajib override ke IP LAN PC, contoh:
  //      flutter run --dart-define=API_BASE_URL=http://192.168.1.9:3006/api/v1
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3006/api/v1';
    }
    return 'http://localhost:3006/api/v1';
  }

  final http.Client _client = http.Client();

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      throw ApiException(
        'Gagal terhubung ke server.\n$baseUrl\n'
        'Pastikan server sudah jalan dan base URL-nya benar.',
      );
    }
  }

  dynamic _decode(http.Response res) {
    final dynamic body =
        res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }

    final message = body is Map && body['message'] != null
        ? body['message'].toString()
        : 'Request gagal (HTTP ${res.statusCode})';

    final errors = body is Map ? body['errors'] : null;
    if (errors is List && errors.isNotEmpty) {
      final details = errors
          .map((e) => e is Map ? '- ${e['field']}: ${e['message']}' : '- $e')
          .join('\n');
      throw ApiException('$message\n$details');
    }

    throw ApiException(message);
  }

  /// Nentuin content-type file berdasarkan ekstensinya.
  /// Server (multer) hanya nerima file yang mimetype-nya diawali "image/".
  MediaType _imageMediaType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
        return MediaType('image', 'heic');
      default:
        return MediaType('image', 'jpeg');
    }
  }

  Future<List<Post>> getPosts() async {
    final res = await _request(() => _client.get(Uri.parse('$baseUrl/posts')));
    final body = _decode(res);

    final list = (body['data']?['posts'] as List<dynamic>?) ?? const [];
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Post> getPost(int id) async {
    final res = await _request(
      () => _client.get(Uri.parse('$baseUrl/posts/$id')),
    );
    final body = _decode(res);

    return Post.fromJson(body['data']['post'] as Map<String, dynamic>);
  }

  /// Ambil daftar user, dipakai buat dropdown "Penulis" di form artikel.
  Future<List<User>> getUsers() async {
    final res = await _request(() => _client.get(Uri.parse('$baseUrl/users')));
    final body = _decode(res);

    final list = (body['data']?['users'] as List<dynamic>?) ?? const [];
    return list.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Buat artikel baru. Gambar OPSIONAL — kalau [imageBytes] null,
  /// artikel tetap dibuat tanpa gambar (field image cukup dikosongkan).
  Future<Post> createPost({
    required int userId,
    required String title,
    required String content,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/posts'))
      ..fields['userId'] = userId.toString()
      ..fields['title'] = title
      ..fields['content'] = content;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final filename = imageFilename ?? 'gambar.jpg';
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
          contentType: _imageMediaType(filename),
        ),
      );
    }

    final streamed = await _request(() => request.send());
    final res = await http.Response.fromStream(streamed);
    final body = _decode(res);

    return Post.fromJson(body['data']['post'] as Map<String, dynamic>);
  }

  /// Update artikel. Gambar juga OPSIONAL — kalau user gak pilih gambar baru,
  /// gambar lama yang di database tetap dipakai.
  Future<Post> updatePost(
    int id, {
    required String title,
    required String content,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/posts/$id'),
    )
      ..fields['title'] = title
      ..fields['content'] = content;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final filename = imageFilename ?? 'gambar.jpg';
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
          contentType: _imageMediaType(filename),
        ),
      );
    }

    final streamed = await _request(() => request.send());
    final res = await http.Response.fromStream(streamed);
    final body = _decode(res);

    return Post.fromJson(body['data']['post'] as Map<String, dynamic>);
  }

  Future<void> deletePost(int id) async {
    final res = await _request(
      () => _client.delete(Uri.parse('$baseUrl/posts/$id')),
    );
    _decode(res);
  }
}
