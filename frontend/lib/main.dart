import 'package:flutter/material.dart';
import 'pages/search_page.dart';

void main() {
  runApp(const EasyTourApp());
}

class EasyTourApp extends StatelessWidget {
  const EasyTourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyTour',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2F5597),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F5597),
        ),
        useMaterial3: true,
      ),
      home: const SearchPage(),
    );
  }
}