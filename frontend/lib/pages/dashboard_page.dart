import 'package:flutter/material.dart';

import '../models/user.dart';
import '../widgets/easytour_header.dart';
import 'login_page.dart';

/*
  Dashboard comunale - SEGNAPOSTO Fase 1.

  Per ora conferma solo che il login operatore funziona e mostra
  l'utente e il Comune gestito. In Fase 2 verrà riempita con:
   - dati aggregati itinerari salvati (RF-C2)
   - luoghi più presenti (RF-C3) / da valorizzare (RF-C4)
   - filtri più usati (RF-C5)
   - segnalazioni ricevute (RF-C6/C7)
*/
class DashboardPage extends StatelessWidget {
  final User user;

  const DashboardPage({super.key, required this.user});

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color lightBackground = Color(0xFFF7FAFC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: Column(
        children: [
          EasyTourHeader(
            rightIcon: Icons.logout,
            onRightIconTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dashboard comunale',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Benvenuta/o, ${user.nome}',
                    style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow('Ruolo', 'Operatore comunale'),
                        const SizedBox(height: 8),
                        _infoRow('Email', user.email),
                        const SizedBox(height: 8),
                        _infoRow('Comune gestito', user.municipalityId ?? '-'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      'Le statistiche del Comune saranno disponibili a breve.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: primaryBlue,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
