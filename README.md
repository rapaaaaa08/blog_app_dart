# Blog App — Aplikasi Mobile Flutter

Aplikasi mobile untuk mengelola artikel blog: **lihat daftar artikel, lihat detail, buat, edit, dan
hapus artikel**. Semua datanya diambil dari REST API lewat HTTP + JSON, jadi tidak ada data yang
di-hardcode di aplikasi.

> Aplikasi ini butuh **backend REST API** yang jalan terpisah (default di `http://localhost:3006`).
> Kalau backend-nya belum jalan, aplikasi akan menampilkan pesan gagal terhubung ke server.

---

## Fitur

| Fitur | Halaman | Request ke API |
| --- | --- | --- |
| Daftar artikel + pull to refresh | `lib/pages/post_list_page.dart` | `GET /posts` |
| Detail artikel | `lib/pages/post_detail_page.dart` | `GET /posts/:id` |
| Buat artikel | `lib/pages/post_form_page.dart` (mode baru) | `POST /posts` |
| Edit artikel | `lib/pages/post_form_page.dart` (mode edit) | `PUT /posts/:id` |
| Hapus artikel + dialog konfirmasi | `lib/pages/post_detail_page.dart` | `DELETE /posts/:id` |
| Pilih penulis artikel (dropdown) | `lib/pages/post_form_page.dart` | `GET /users` |
| Upload gambar (opsional) | `lib/pages/post_form_page.dart` | `multipart/form-data`, field `image` |

Kartu artikel menampilkan gambar (kalau ada), judul, cuplikan caption, chip kategori, nama penulis,
dan tanggal. **Tidak ada fitur login/register** — aplikasi langsung masuk ke daftar artikel.

## Teknologi

| Library | Fungsi |
| --- | --- |
| `http` | Memanggil REST API |
| `provider` | State management (`PostProvider` sebagai `ChangeNotifier`) |
| `image_picker` | Memilih gambar dari galeri/kamera |
| `http_parser` | Menentukan `Content-Type` file gambar saat upload |
| `flutter_lints` | Aturan lint (`analysis_options.yaml`) |

## Struktur Folder

```
lib/
├── main.dart                       # Titik masuk: ChangeNotifierProvider + MaterialApp
├── models/
│   ├── post.dart                   # Model Post + parsing JSON, getter caption & formattedDate
│   └── user.dart                   # Model User buat dropdown penulis
├── services/
│   └── api_service.dart            # Semua request HTTP + penentuan base URL + ApiException
├── providers/
│   └── post_provider.dart          # State aplikasi: daftar, detail, user, loading, error, CRUD
└── pages/
    ├── post_list_page.dart         # Halaman daftar artikel
    ├── post_detail_page.dart       # Halaman detail + tombol Edit & Hapus
    └── post_form_page.dart         # Form buat/edit artikel + pilih gambar
```

## Alur Data

```
Widget / Page
    │  context.read<PostProvider>() / context.watch<PostProvider>()
    ▼
PostProvider (ChangeNotifier)     ← nyimpen daftar artikel, detail, status loading, dan error
    │
    ▼
ApiService (package:http)         ← parsing JSON, lempar ApiException kalau gagal
    │
    ▼
REST API  http://<base-url>/api/v1
```

Halaman tidak memanggil API langsung — semuanya lewat `PostProvider`, jadi logika request tidak
berserakan di dalam widget.

## Cara Menjalankan

### 1. Prasyarat

- Flutter SDK (Dart `^3.13.3`)
- Backend REST API sudah jalan di port `3006`

### 2. Install dependency

```bash
flutter pub get
```

### 3. Base URL otomatis

`lib/services/api_service.dart` memilih alamat API sesuai target yang dipakai:

| Target | Base URL |
| --- | --- |
| Chrome / Edge / Windows | `http://localhost:3006/api/v1` |
| Android emulator | `http://10.0.2.2:3006/api/v1` |
| HP fisik (satu WiFi dengan PC) | wajib di-override manual |

Kalau perlu override (misal untuk HP fisik):

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.9:3006/api/v1
```

### 4. Jalankan aplikasi

```bash
flutter run -d chrome     # paling cepat buat ngetes
flutter run -d windows    # Windows desktop
flutter run               # Android emulator (base URL otomatis 10.0.2.2)
```

### 5. Cek kualitas kode

```bash
flutter analyze
```

## Testing

```bash
flutter test
```

Ada **7 test** dan semuanya jalan tanpa perlu server, karena API-nya di-fake pakai `FakeApiService`
(data disimpan di memori):

| File | Isi |
| --- | --- |
| `test/post_model_test.dart` | 3 unit test: parsing `Post.fromJson`, `caption` membuang hashtag, dan parsing tetap aman kalau `author`/`categories` kosong |
| `test/post_flow_test.dart` | 4 widget test: daftar artikel tampil dari API, caption tanpa hashtag, alur detail → edit → hapus, dan alur buat artikel baru |

## Endpoint yang Dipakai

Base URL: `http://localhost:3006/api/v1`

| Method | Endpoint | Dipakai untuk |
| --- | --- | --- |
| `GET` | `/posts` | Daftar artikel |
| `GET` | `/posts/:id` | Detail artikel |
| `POST` | `/posts` | Buat artikel (multipart: `userId`, `title`, `content`, `image` opsional) |
| `PUT` | `/posts/:id` | Update artikel (`title`, `content`, `image` opsional) |
| `DELETE` | `/posts/:id` | Hapus artikel |
| `GET` | `/users` | Isi dropdown penulis |

Response API berformat `{ success, message, data }`. Kalau status code bukan 2xx, `ApiService`
mengubahnya jadi `ApiException` berisi pesan dari server (termasuk detail error validasi).

## Aturan Hashtag → Kategori

Hashtag di konten otomatis jadi kategori di sisi backend (`#kuliner` → kategori `kuliner`), dan
dikirim balik ke aplikasi sebagai daftar `categories`.

Di tampilan, hashtag **dibuang dari caption** supaya tidak dobel dengan chip kategori. Ini diatur
getter `Post.caption` di `lib/models/post.dart`:

```dart
content.replaceAll(RegExp(r'#\w+'), '')
```

Konten aslinya tetap utuh di database, jadi waktu artikel diedit hashtag-nya masih terbaca untuk
menentukan kategori.

## Catatan

- **Upload gambar opsional.** Kalau tidak pilih gambar, artikel tetap tersimpan tanpa gambar.
- **Waktu edit**, kalau tidak memilih gambar baru, gambar lama tetap dipakai.
- **Penulis tidak bisa diganti** waktu edit — backend hanya meng-update judul, konten, dan gambar.
- Izin Android sudah diatur di `android/app/src/main/AndroidManifest.xml`:
  `android.permission.INTERNET` + `android:usesCleartextTraffic="true"` supaya boleh mengakses
  alamat `http://` (bukan HTTPS) saat pengujian.
- Pesan error koneksi menampilkan base URL yang sedang dipakai, jadi mempermudah debugging kalau
  backend belum jalan atau alamatnya salah.
