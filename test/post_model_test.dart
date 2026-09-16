import 'package:flutter_test/flutter_test.dart';

import 'package:client/models/post.dart';

void main() {
  test('Post.fromJson membaca field utama dari response API', () {
    final post = Post.fromJson({
      'id': 1,
      'userId': 2,
      'title': 'Kuliner Malam di Jakarta',
      'content': 'Malam minggu enaknya cari makanan. #kuliner #jakarta',
      'imageUrl': null,
      'status': 'published',
      'createdAt': '2026-09-13T22:24:05.000Z',
      'author': {'id': 2, 'username': 'rafa', 'avatarUrl': null},
      'categories': ['kuliner', 'jakarta'],
    });

    expect(post.id, 1);
    expect(post.userId, 2);
    expect(post.title, 'Kuliner Malam di Jakarta');
    expect(post.authorUsername, 'rafa');
    expect(post.categories, ['kuliner', 'jakarta']);
    expect(post.formattedDate, isNot('-'));
  });

  test('caption membuang hashtag (hashtag pindah ke kategori)', () {
    const post = Post(
      id: 1,
      userId: 1,
      title: 'Mukbang',
      content: 'Lagi makan enak nih #mukbang #kuliner',
    );

    expect(post.caption, 'Lagi makan enak nih');
    expect(post.caption.contains('#'), isFalse);
  });

  test('Post.fromJson tetap aman kalau author/categories kosong', () {
    final post = Post.fromJson({
      'id': 5,
      'userId': 1,
      'title': 'Tanpa kategori',
      'content': 'Isi artikel',
    });

    expect(post.authorUsername, isNull);
    expect(post.categories, isEmpty);
    expect(post.formattedDate, '-');
  });
}
