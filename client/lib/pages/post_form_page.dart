import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/post.dart';
import '../providers/post_provider.dart';

class PostFormPage extends StatefulWidget {
  const PostFormPage({super.key, this.post});

  /// null  -> mode buat artikel baru
  /// terisi -> mode edit artikel
  final Post? post;

  @override
  State<PostFormPage> createState() => _PostFormPageState();
}

class _PostFormPageState extends State<PostFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  /// Penulis artikel yang dipilih dari dropdown (diambil dari API).
  int? _selectedUserId;

  // Gambar OPSIONAL: kalau null, artikel disimpan tanpa gambar
  // (waktu edit, gambar lama di database tetap dipakai).
  Uint8List? _imageBytes;
  String? _imageFilename;

  bool get _isEdit => widget.post != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post?.title ?? '');
    _contentController = TextEditingController(
      text: widget.post?.content ?? '',
    );
    _selectedUserId = widget.post?.userId;

    // Ambil daftar penulis dari API (hanya perlu sekali per sesi).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PostProvider>().loadUsers();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _imageFilename = picked.name;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar: $error')),
      );
    }
  }

  void _clearPickedImage() {
    setState(() {
      _imageBytes = null;
      _imageFilename = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<PostProvider>();

    // Nentuin penulis: waktu edit pakai penulis lama (server tidak
    // mengizinkan ganti penulis), waktu buat baru pakai pilihan dropdown.
    final int? authorId = _isEdit
        ? widget.post!.userId
        : (_selectedUserId ??
              (provider.users.isNotEmpty ? provider.users.first.id : null));

    if (authorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daftar penulis belum termuat. Coba muat ulang halaman.'),
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    try {
      if (_isEdit) {
        await provider.updatePost(
          widget.post!.id,
          title: title,
          content: content,
          imageBytes: _imageBytes,
          imageFilename: _imageFilename,
        );
      } else {
        await provider.createPost(
          userId: authorId,
          title: title,
          content: content,
          imageBytes: _imageBytes,
          imageFilename: _imageFilename,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Artikel berhasil diupdate' : 'Artikel berhasil dibuat',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostProvider>();
    final isSaving = provider.isSaving;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Artikel' : 'Tulis Artikel'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAuthorField(context, provider),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Judul',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Judul wajib diisi';
                if (text.length < 3) return 'Judul minimal 3 karakter';
                if (text.length > 255) return 'Judul maksimal 255 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Konten / Caption',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Konten wajib diisi';
                if (text.length < 10) return 'Konten minimal 10 karakter';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Hashtag di konten otomatis jadi kategori, contoh: #kuliner #jakarta',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),

            // ---------- Gambar (opsional) ----------
            Text(
              'Gambar (opsional)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _buildImagePreview(context),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: isSaving ? null : _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: Text(
                    _imageBytes == null ? 'Pilih Gambar' : 'Ganti Gambar',
                  ),
                ),
                if (_imageBytes != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: isSaving ? null : _clearPickedImage,
                    icon: const Icon(Icons.close),
                    label: const Text('Batal pilih'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: isSaving ? null : _save,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(isSaving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dropdown penulis, diisi dari `GET /users`.
  Widget _buildAuthorField(BuildContext context, PostProvider provider) {
    // Waktu edit, penulis tidak bisa diganti (server hanya meng-update
    // judul, konten, dan gambar).
    if (_isEdit) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Penulis',
          border: OutlineInputBorder(),
          helperText: 'Penulis tidak bisa diubah saat mengedit',
        ),
        child: Text(widget.post?.authorUsername ?? '-'),
      );
    }

    if (provider.isLoadingUsers && provider.users.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Penulis',
          border: OutlineInputBorder(),
        ),
        child: Text('Memuat daftar penulis...'),
      );
    }

    if (provider.users.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Penulis',
          border: const OutlineInputBorder(),
          errorText:
              provider.usersErrorMessage ?? 'Daftar penulis tidak tersedia',
        ),
        child: const Text('-'),
      );
    }

    final selected =
        _selectedUserId != null &&
            provider.users.any((user) => user.id == _selectedUserId)
        ? _selectedUserId
        : provider.users.first.id;

    return DropdownButtonFormField<int>(
      initialValue: selected,
      decoration: const InputDecoration(
        labelText: 'Penulis',
        border: OutlineInputBorder(),
      ),
      items: provider.users
          .map(
            (user) => DropdownMenuItem<int>(
              value: user.id,
              child: Text(user.username),
            ),
          )
          .toList(),
      onChanged: provider.isSaving
          ? null
          : (value) => setState(() => _selectedUserId = value),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    final existingUrl = widget.post?.imageUrl;

    if (_imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _imageBytes!,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    if (existingUrl != null && existingUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          existingUrl,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _emptyImageBox(context, 'Gambar lama gagal dimuat'),
        ),
      );
    }

    return _emptyImageBox(context, 'Belum ada gambar (boleh dikosongkan)');
  }

  Widget _emptyImageBox(BuildContext context, String text) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
