import 'package:flutter/material.dart';

class EasyTourHeader extends StatelessWidget {
  // Parametri esistenti (retrocompatibili): slot icona a destra generico,
  // usato da search_page (verifica/lucchetto) e place_detail (back).
  final IconData? rightIcon;
  final VoidCallback? onRightIconTap;

  // Nuovi parametri opzionali.
  // showBack: mostra un tasto "indietro" a sinistra del logo.
  // onBackTap: cosa fa il tasto indietro (default: Navigator.pop).
  // showLogout / onLogoutTap: mostra un tasto logout a destra.
  final bool showBack;
  final VoidCallback? onBackTap;
  final bool showLogout;
  final VoidCallback? onLogoutTap;

  const EasyTourHeader({
    super.key,
    this.rightIcon,
    this.onRightIconTap,
    this.showBack = false,
    this.onBackTap,
    this.showLogout = false,
    this.onLogoutTap,
  });

  static const Color orange = Color(0xFFF58A00);
  static const Color primaryBlue = Color(0xFF005A8D);

  @override
    Widget build(BuildContext context) {
      return Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              // Logo tutto a sinistra
              Image.asset(
                'assets/images/easytour_logo2.jpg',
                height: 110,
                fit: BoxFit.contain,
              ),

              const Spacer(),

              // Slot icona generico esistente (retrocompatibile)
              if (rightIcon != null)
                InkWell(
                  onTap: onRightIconTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      rightIcon,
                      color: orange,
                    ),
                  ),
                ),

              // Tasto logout (opzionale), a destra
              if (showLogout)
                Padding(
                  padding: EdgeInsets.only(left: rightIcon != null ? 8 : 0),
                  child: InkWell(
                    onTap: onLogoutTap,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: orange,
                      ),
                    ),
                  ),
                ),

              // Tasto indietro (opzionale), ora a destra
              if (showBack)
                Padding(
                  padding: EdgeInsets.only(left: showLogout ? 8 : 0),
                  child: InkWell(
                    onTap: onBackTap ?? () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
}