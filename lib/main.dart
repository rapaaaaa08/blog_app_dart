import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/post_list_page.dart';
import 'providers/post_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => PostProvider(),
      child: const BlogApp(),
    ),
  );
}

class BlogApp extends StatelessWidget {
  const BlogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blog App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PostListPage(),
    );
  }
}
