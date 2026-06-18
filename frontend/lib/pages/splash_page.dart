import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'login_page.dart';

/// Splash — versione MODERNA.
/// Profondità a strati: una griglia-mappa tenue come texture di fondo,
/// una fascia di gradiente morbida solo in basso (il centro resta bianco
/// per non mostrare il bordo del JPG), il logo in un alone bianco con
/// ombra netta, e un pin che "atterra" sul posto con un piccolo rimbalzo —
/// la metafora dell'arrivo a destinazione.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBlue = Color(0xFFEAF4FA);

  late final AnimationController _entryController;
  late final AnimationController _pinController;
  late final AnimationController _shimmerController;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _taglineFade;
  late final Animation<double> _pinDrop;
  late final Animation<double> _pinFade;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _pinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _logoFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    _pinDrop = Tween<double>(begin: -60, end: 0).animate(
      CurvedAnimation(parent: _pinController, curve: Curves.bounceOut),
    );

    _pinFade = CurvedAnimation(
      parent: _pinController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );

    _entryController.forward();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _pinController.forward();
    });

    Timer(const Duration(milliseconds: 3000), _goToLogin);
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, animation, __) => const LoginPage(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pinController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Griglia-mappa tenue su tutto lo sfondo.
          Positioned.fill(
            child: CustomPaint(painter: _MapGridPainter()),
          ),

          // Fascia gradiente solo in basso — profondità senza toccare il centro.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.42,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0),
                    lightBlue.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),

          // Curva "orizzonte" morbida sopra la fascia.
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * 0.30,
            child: CustomPaint(
              size: Size(size.width, 70),
              painter: _HorizonPainter(),
            ),
          ),

          // Contenuto centrale.
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo + pin che cade sopra.
                SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withOpacity(0.12),
                                  blurRadius: 34,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/easytour_logo2_trasparente.png',
                              width: 180,
                              height: 180,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      // Pin che atterra sul bordo alto del logo.
                      Positioned(
                        top: 6,
                        child: AnimatedBuilder(
                          animation: _pinController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _pinFade.value,
                              child: Transform.translate(
                                offset: Offset(0, _pinDrop.value),
                                child: child,
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: orange,
                            size: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 110),
                _buildSuitcaseLoader(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Barra di caricamento con riflesso che scorre.
  // Loader: valigie che scorrono in continuo, nei colori del logo.
    Widget _buildSuitcaseLoader() {
      const icons = [
        Icons.luggage_rounded,
        Icons.work_rounded,
        Icons.luggage_rounded,
        Icons.business_center_rounded,
      ];
      const colors = [primaryBlue, orange, darkBlue, orange];

      return FadeTransition(
        opacity: _logoFade,
        child: SizedBox(
          width: 150,
          height: 34,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                final v = _shimmerController.value;
                // Le valigie entrano da destra ed escono a sinistra.
                return Stack(
                  children: List.generate(icons.length, (i) {
                    // posizione di ogni valigia, sfasata e ciclica
                    final spacing = 1.0 / icons.length;
                    final t = (v + i * spacing) % 1.0;
                    final x = -30 + t * (150 + 30); // da 150 (fuori dx) a -30 (fuori sx)
                    // dissolvenza ai bordi per entrata/uscita morbida
                    double opacity = 1.0;
                    if (t < 0.12) opacity = t / 0.12;
                    if (t > 0.88) opacity = (1.0 - t) / 0.12;
                    return Positioned(
                      left: x,
                      top: 4,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Icon(
                          icons[i],
                          color: colors[i],
                          size: 24,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      );
    }
  }

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF005A8D).withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const step = 46.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HorizonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF58A00).withOpacity(0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()..moveTo(0, size.height);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.1,
      size.width,
      size.height,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}