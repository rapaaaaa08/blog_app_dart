/// Data user sederhana, dipakai buat dropdown "Penulis" waktu bikin artikel.
class User {
  final int id;
  final String username;

  const User({required this.id, required this.username});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String? ?? '-',
    );
  }
}
