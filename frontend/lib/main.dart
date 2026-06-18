import 'package:flutter/material.dart';
import 'pages/splash_page.dart';
import 'models/user.dart';
import 'pages/dashboard_page.dart';
import 'pages/dashboard_utente.dart';
import 'pages/login_page.dart';
import 'services/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bool isLoggedIn = await SessionService.loadSession();

  runApp(
    EasyTourApp(
      isLoggedIn: isLoggedIn,
    ),
  );
}

class EasyTourApp extends StatelessWidget {
  final bool isLoggedIn;

  const EasyTourApp({
    super.key,
    required this.isLoggedIn,
  });

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
      home: isLoggedIn ? const SessionRedirectPage() : const SplashPage(),
    );
  }
}

class SessionRedirectPage extends StatelessWidget {
  const SessionRedirectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = User(
      id: SessionService.currentUserId ?? '',
      nome: SessionService.currentUsername ?? '',
      email: SessionService.currentEmail ?? '',
      ruolo: SessionService.currentRole ?? 'TURISTA',
    );

    final token = SessionService.authToken ?? '';

    if (user.isOperatore) {
      return DashboardPage(
        user: user,
        token: token,
      );
    }

    return DashboardUtente(
      user: user,
      token: token,
    );
  }
}