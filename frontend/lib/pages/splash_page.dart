import 'dart:async';

import 'package:flutter/material.dart';

import 'login_page.dart';

/// Splash — versione MODERNA.
/// Profondità a strati: la mappa del mondo (la tua immagine) tenuissima
/// come texture di fondo, una fascia di gradiente morbida solo in basso
/// (il centro resta bianco per non mostrare il bordo del JPG), il logo
/// in un alone bianco con ombra netta, un pin che "atterra" sul posto con
/// un piccolo rimbalzo, e un aereo che sorvola la curva dell'orizzonte da
/// sinistra a destra — la metafora del viaggio e dell'arrivo a destinazione.
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
  late final AnimationController _planeController;

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

    // Controller dedicato al volo dell'aereo lungo la curva dell'orizzonte.
    _planeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
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

    Timer(const Duration(milliseconds: 5000), _goToLogin);
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
    _planeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const horizonAreaHeight = 70.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Mappa reale (la tua immagine) tenue su tutto lo sfondo:
          // restiamo sui colori originali del jpg (blu su bianco) e
          // giochiamo solo sull'opacità per renderla una texture leggera.
          // NB: niente ColorFiltered con BlendMode.srcIn qui, perché un
          // .jpg non ha canale alpha e quel filtro riempirebbe l'intero
          // rettangolo con un colore uniforme, rendendo la mappa invisibile.
          Positioned.fill(
            child: Opacity(
              opacity: 0.18,
              child: Image.asset(
                'assets/images/mappa.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
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

          // Curva "orizzonte" morbida sopra la fascia, con l'aereo che la
          // sorvola da sinistra a destra seguendone la traiettoria.
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * 0.30,
            height: horizonAreaHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HorizonPainter(),
                  ),
                ),
                AnimatedBuilder(
                  animation: _planeController,
                  builder: (context, child) {
                    final horizonSize = Size(size.width, horizonAreaHeight);
                    final path = _buildHorizonPath(horizonSize);
                    final metric = path.computeMetrics().first;
                    final t = _planeController.value;
                    final tangent = metric.getTangentForOffset(
                      metric.length * t,
                    );
                    if (tangent == null) return const SizedBox.shrink();

                    const planeSize = Size(34, 30);
                    return Positioned(
                      left: tangent.position.dx - planeSize.width / 2,
                      top: tangent.position.dy - planeSize.height / 2,
                      child: Transform.rotate(
                        angle: tangent.angle,
                        child: CustomPaint(
                          size: planeSize,
                          painter: _PlanePainter(color: orange),
                        ),
                      ),
                    );
                  },
                ),
              ],
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

/// Genera il path della curva "orizzonte", condiviso sia dal painter che
/// disegna la linea sia dal calcolo della posizione/angolo dell'aereo, così
/// restano sempre perfettamente sovrapposti.
Path _buildHorizonPath(Size size) {
  final path = Path()..moveTo(0, size.height);
  path.quadraticBezierTo(
    size.width * 0.5,
    size.height * 0.1,
    size.width,
    size.height,
  );
  return path;
}

class _HorizonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF58A00).withOpacity(0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(_buildHorizonPath(size), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Aereo visto dall'alto, disegnato con il muso rivolto verso destra
/// (direzione +x) quando l'angolo di rotazione è zero: fusoliera
/// affusolata, ali principali a freccia e ali di coda più piccole, come
/// la sagoma di un aereo vista da sopra. Viene poi ruotato dall'esterno
/// in base alla tangente della curva, così segue fedelmente la
/// traiettoria mantenendo sempre il muso nel verso di marcia.
class _PlanePainter extends CustomPainter {
  final Color color;

  _PlanePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final hw = size.width / 2;
    final hh = size.height / 2;

    canvas.save();
    canvas.translate(hw, hh);

    // Profilo superiore della sagoma, dal muso verso la coda: fusoliera,
    // ala principale a freccia, rastremazione verso coda, ala di coda
    // più piccola, punta di coda.
    final upper = <Offset>[
      Offset(hw * 1.00, 0), // muso
      Offset(hw * 0.55, hh * 0.10), // spalla fusoliera
      Offset(hw * 0.38, hh * 0.12), // attacco ala principale
      Offset(hw * 0.10, hh * 1.00), // estremità ala principale
      Offset(hw * -0.05, hh * 0.30), // bordo d'uscita ala principale
      Offset(hw * -0.45, hh * 0.16), // rastremazione fusoliera
      Offset(hw * -0.62, hh * 0.55), // estremità ala di coda (timone)
      Offset(hw * -0.85, hh * 0.20), // bordo d'uscita ala di coda
      Offset(hw * -1.00, hh * 0.06), // punta di coda
      Offset(hw * -1.00, 0), // centro coda
    ];

    final path = Path()..moveTo(upper.first.dx, upper.first.dy);
    for (final p in upper.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    // Specchia il profilo sul lato inferiore per ottenere una sagoma
    // simmetrica, tornando verso il muso.
    for (final p in upper.reversed.skip(1)) {
      path.lineTo(p.dx, -p.dy);
    }
    path.close();

    // Piccola fusoliera centrale più stretta, per dare profondità alla
    // sagoma (linea sottile dal muso alla coda).
    final spine = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.05;
    canvas.drawLine(
      Offset(hw * 0.95, 0),
      Offset(hw * -0.95, 0),
      spine,
    );

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlanePainter oldDelegate) =>
      oldDelegate.color != color;
}