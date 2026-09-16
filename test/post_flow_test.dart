import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:client/main.dart';
import 'package:client/models/post.dart';
import 'package:client/models/user.dart';
import 'package:client/providers/post_provider.dart';
import 'package:client/services/api_service.dart';

/// API palsu yang nyimpen data di memori, biar alur UI bisa dites
/// tanpa perlu server + device beneran.
class FakeApiService extends ApiService {
  final List<Post> store = [
    const Post(
      id: 1,
      userId: 2,
      title: 'Kuliner Malam di Jakarta',
      content: 'Malam minggu enaknya cari makanan. #kuliner #jakarta',
      authorUsername: 'rafa',
      categories: ['kuliner', 'jakarta'],
    ),
  ];

  int _nextId = 2;

  @override
  Future<List<Post>> getPosts() async => List.of(store);

  @override
  Future<List<User>> getUsers() async => const [
    User(id: 1, username: 'admin'),
    User(id: 2, username: 'rafa'),
  ];

  @override
  Future<Post> getPost(int id) async =>
      store.firstWhere((post) => post.id == id);

  @override
  Future<Post> createPost({
    required int userId,
    required String title,
    required String content,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    final post = Post(
      id: _nextId++,
      userId: userId,
      title: title,
      content: content,
      authorUsername: 'admin',
      imageUrl: imageBytes == null ? null : 'https://contoh.com/gambar.jpg',
      categories: const ['baru'],
    );
    store.insert(0, post);
    return post;
  }

  @override
  Future<Post> updatePost(
    int id, {
    required String title,
    required String content,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    final index = store.indexWhere((post) => post.id == id);
    final old = store[index];
    final updated = Post(
      id: old.id,
      userId: old.userId,
      title: title,
      content: content,
      authorUsername: old.authorUsername,
      imageUrl: imageBytes == null
          ? old.imageUrl
          : 'https://contoh.com/gambar-baru.jpg',
      categories: const ['diubah'],
    );
    store[index] = updated;
    return updated;
  }

  @override
  Future<void> deletePost(int id) async {
    store.removeWhere((post) => post.id == id);
  }
}

Widget buildApp(ApiService api) {
  return ChangeNotifierProvider(
    create: (_) => PostProvider(api: api),
    child: const BlogApp(),
  );
}

/// Render app dengan layar besar biar semua tombol (termasuk "Simpan" yang
/// ada di bawah form) ikut kebangun oleh ListView.
Future<void> pumpApp(WidgetTester tester, ApiService api) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(buildApp(api));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('daftar artikel tampil dari API', (tester) async {
    await pumpApp(tester, FakeApiService());

    expect(find.text('Daftar Artikel'), findsOneWidget);
    expect(find.text('Kuliner Malam di Jakarta'), findsOneWidget);
    expect(find.textContaining('oleh rafa'), findsOneWidget);
    expect(find.text('#kuliner'), findsOneWidget);
  });

  testWidgets('caption tampil tanpa hashtag (hashtag jadi kategori)', (
    tester,
  ) async {
    await pumpApp(tester, FakeApiService());

    // hashtag gak muncul di caption...
    expect(
      find.text('Malam minggu enaknya cari makanan.'),
      findsOneWidget,
    );
    // ...tapi muncul sebagai chip kategori
    expect(find.text('#kuliner'), findsOneWidget);
    expect(find.text('#jakarta'), findsOneWidget);
  });

  testWidgets('alur detail -> edit -> hapus', (tester) async {
    final api = FakeApiService();
    await pumpApp(tester, api);

    // 1) buka detail
    await tester.tap(find.text('Kuliner Malam di Jakarta'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Artikel'), findsOneWidget);

    // 2) edit artikel
    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Artikel'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Judul Setelah Edit',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(api.store.first.title, 'Judul Setelah Edit');
    expect(find.text('Judul Setelah Edit'), findsWidgets);

    // 3) hapus artikel
    await tester.tap(find.widgetWithText(OutlinedButton, 'Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus artikel?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();

    expect(api.store, isEmpty);
    expect(find.text('Daftar Artikel'), findsOneWidget);
    expect(find.textContaining('Belum ada artikel'), findsOneWidget);
  });

  testWidgets('alur buat artikel baru', (tester) async {
    final api = FakeApiService();
    await pumpApp(tester, api);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Tulis'));
    await tester.pumpAndSettle();
    expect(find.text('Tulis Artikel'), findsOneWidget);

    // dropdown penulis terisi dari GET /users
    expect(find.text('admin'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Artikel Baru');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Isi artikel baru dengan hashtag #baru',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(api.store.length, 2);
    expect(api.store.first.content, contains('#baru'));
    // penulis default = user pertama dari dropdown
    expect(api.store.first.userId, 1);
    expect(find.text('Daftar Artikel'), findsOneWidget);
    expect(find.text('Artikel Baru'), findsOneWidget);
  });
}
