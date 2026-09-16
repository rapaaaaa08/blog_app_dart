import 'package:flutter/foundation.dart';

import '../models/post.dart';
import '../models/user.dart';
import '../services/api_service.dart';

/// Satu tempat buat semua data artikel + operasi CRUD.
///
/// Halaman (UI) cuma perlu dengerin perubahan dari class ini lewat
/// `context.watch<PostProvider>()`, jadi logika API gak berserakan di widget.
class PostProvider extends ChangeNotifier {
  PostProvider({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  // ---------- State: daftar artikel ----------
  List<Post> _posts = const [];
  List<Post> get posts => _posts;

  bool _isLoadingList = false;
  bool get isLoadingList => _isLoadingList;

  // ---------- State: detail artikel ----------
  Post? _selectedPost;
  Post? get selectedPost => _selectedPost;

  bool _isLoadingDetail = false;
  bool get isLoadingDetail => _isLoadingDetail;

  // ---------- State: daftar user (buat pilih penulis artikel) ----------
  List<User> _users = const [];
  List<User> get users => _users;

  bool _isLoadingUsers = false;
  bool get isLoadingUsers => _isLoadingUsers;

  String? _usersErrorMessage;
  String? get usersErrorMessage => _usersErrorMessage;

  // ---------- State: proses simpan / hapus ----------
  bool _isSaving = false;
  bool get isSaving => _isSaving;

  // ---------- Pesan error (null = gak ada error) ----------
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Ambil daftar user buat dropdown "Penulis".
  /// Cukup sekali per sesi, jadi hasilnya di-cache (kecuali [force] = true).
  Future<void> loadUsers({bool force = false}) async {
    if (_users.isNotEmpty && !force) return;

    _isLoadingUsers = true;
    _usersErrorMessage = null;
    notifyListeners();

    try {
      _users = await _api.getUsers();
    } catch (error) {
      _usersErrorMessage = error.toString();
      _users = const [];
    } finally {
      _isLoadingUsers = false;
      notifyListeners();
    }
  }

  /// Ambil semua artikel dari API (dipakai halaman daftar).
  Future<void> loadPosts() async {
    _isLoadingList = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _posts = await _api.getPosts();
    } catch (error) {
      _errorMessage = error.toString();
      _posts = const [];
    } finally {
      _isLoadingList = false;
      notifyListeners();
    }
  }

  /// Ambil 1 artikel (dipakai halaman detail).
  Future<void> loadPost(int id) async {
    _isLoadingDetail = true;
    _errorMessage = null;
    _selectedPost = null;
    notifyListeners();

    try {
      _selectedPost = await _api.getPost(id);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  /// Buat artikel baru, lalu refresh daftar.
  /// [imageBytes] boleh null = artikel dibuat tanpa gambar.
  Future<void> createPost({
    required int userId,
    required String title,
    required String content,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      await _api.createPost(
        userId: userId,
        title: title,
        content: content,
        imageBytes: imageBytes,
        imageFilename: imageFilename,
      );
      _posts = await _api.getPosts();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Update artikel, lalu refresh daftar & halaman detail (kalau sedang dibuka).
  /// Kalau [imageBytes] null, gambar lama tetap dipakai.
  Future<void> updatePost(
    int id, {
    required String title,
    required String content,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      await _api.updatePost(
        id,
        title: title,
        content: content,
        imageBytes: imageBytes,
        imageFilename: imageFilename,
      );
      _posts = await _api.getPosts();
      if (_selectedPost?.id == id) {
        _selectedPost = await _api.getPost(id);
      }
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Hapus artikel, lalu refresh daftar.
  Future<void> deletePost(int id) async {
    _isSaving = true;
    notifyListeners();

    try {
      await _api.deletePost(id);
      _posts = await _api.getPosts();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
