import 'package:flutter/material.dart';

import 'viewmodels/library_view_model.dart';
import 'views/library_screen.dart';

void main() {
  runApp(const LibraryApp());
}

class LibraryApp extends StatelessWidget {
  const LibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Perpustakaan Kampus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF315C4B),
          surface: const Color(0xFFF7F8F5),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
      ),
      home: LibraryScreen(viewModel: LibraryViewModel()),
    );
  }
}
