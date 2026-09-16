class Post {
  final int id;
  final int userId;
  final String title;
  final String content;
  final String? imageUrl;
  final String status;
  final String? createdAt;
  final String? authorUsername;
  final List<String> categories;

  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.imageUrl,
    this.status = 'published',
    this.createdAt,
    this.authorUsername,
    this.categories = const [],
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final author = json['author'];

    return Post(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '-',
      content: json['content'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      status: json['status'] as String? ?? 'published',
      createdAt: json['createdAt'] as String?,
      authorUsername:
          author is Map<String, dynamic> ? author['username'] as String? : null,
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  /// Konten yang dipakai buat ditampilkan di UI.
  ///
  /// Hashtag (#mukbang, #kuliner, dst) DIBUANG dari caption karena sudah
  /// tampil sebagai chip kategori. Konten asli tetap utuh di database,
  /// jadi waktu edit hashtag-nya masih kebaca buat nentuin kategori.
  String get caption {
    final cleaned = content
        .replaceAll(RegExp(r'#\w+'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();

    // Kalau isinya cuma hashtag doang, tampilkan apa adanya biar gak kosong.
    return cleaned.isEmpty ? content.trim() : cleaned;
  }

  String get formattedDate {
    final raw = createdAt;
    if (raw == null) return '-';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
