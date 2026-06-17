import 'package:flutter/material.dart';

import '../models/user.dart';
import 'login_page.dart';
import 'search_page.dart';

/*
  Dashboard utente (turista).
  Schermata "home" mostrata al turista dopo il login.
  Tre azioni: logout (in alto a destra), cerca luoghi, i miei itinerari.

  Non richiede backend: è solo navigazione. I dati degli itinerari
  verranno caricati dalla pagina "I miei itinerari" quando sarà pronta.
*/
class DashboardUtente extends StatelessWidget {
  final User user;
  final String token;

  const DashboardUtente({super.key, required this.user, required this.token});

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBackground = Color(0xFFF4F7FA);

  void _logout(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _goToSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchPage()),
    );
  }

  void _goToMyItineraries(BuildContext context) {
    // Placeholder: la pagina "I miei itinerari" non è ancora pronta.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La sezione "I miei itinerari" sarà disponibile a breve.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra in alto: logo + logout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: orange, size: 28),
                      const SizedBox(width: 6),
                      const Text(
                        'EasyTour',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: primaryBlue),
                    tooltip: 'Esci',
                    onPressed: () => _logout(context),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Saluto
              Text(
                'Ciao, ${user.nome}!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cosa vuoi fare oggi?',
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),

              const SizedBox(height: 36),

              // Pulsante: cerca luoghi
              _actionCard(
                context: context,
                icon: Icons.search_rounded,
                iconBg: const Color(0xFFE3EEF6),
                iconColor: primaryBlue,
                title: 'Cerca luoghi',
                subtitle: 'Trova attrazioni e genera un itinerario',
                onTap: () => _goToSearch(context),
              ),
              const SizedBox(height: 16),

              // Pulsante: i miei itinerari
              _actionCard(
                context: context,
                icon: Icons.map_outlined,
                iconBg: const Color(0xFFFDEFD9),
                iconColor: orange,
                title: 'I miei itinerari',
                subtitle: 'Rivedi i percorsi che hai salvato',
                onTap: () => _goToMyItineraries(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
