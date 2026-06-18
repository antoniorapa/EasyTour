import 'package:flutter/material.dart';

/// EasyTourHeader — versione 2: HERO BLU.
/// Una fascia blu con bordo inferiore ondulato; il logo (JPG su bianco) vive
/// dentro una pastiglia bianca arrotondata così il rettangolo del JPG sparisce.
/// I controlli back/logout/rightIcon diventano bianchi traslucidi su blu.
///
/// Nota mobile: la fascia è alta ma contenuta; sulle pagine interne con
/// back/logout resta comunque leggibile. Tutti i parametri originali invariati.
class EasyTourHeader extends StatelessWidget {
  final IconData? rightIcon;
  final VoidCallback? onRightIconTap;
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
  static const Color darkBlue = Color(0xFF003F63);

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryBlue, darkBlue],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Row(
              children: [
                Image.asset(
                    'assets/images/easytour_logo2_trasparente.png',
                    height: 70,
                    fit: BoxFit.contain,
                  ),
                const Spacer(),
                if (rightIcon != null)
                  _GlassButton(icon: rightIcon!, onTap: onRightIconTap),
                if (showLogout)
                  Padding(
                    padding: EdgeInsets.only(left: rightIcon != null ? 8 : 0),
                    child: _GlassButton(
                      icon: Icons.logout_rounded,
                      onTap: onLogoutTap,
                    ),
                  ),
                if (showBack)
                  Padding(
                    padding: EdgeInsets.only(left: showLogout ? 8 : 0),
                    child: _GlassButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBackTap ?? () => Navigator.of(context).pop(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GlassButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.35)),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

/// Clip a onda morbida per il bordo inferiore della fascia.
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 20);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height - 10,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 22,
      size.width,
      size.height - 6,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}