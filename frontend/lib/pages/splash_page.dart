import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBlue = Color(0xFFEAF4FA);
  static const Color softOrange = Color(0xFFFFF2DF);
  static const Color softGrey = Color(0xFFF7FAFC);

  late final AnimationController _logoController;
  late final AnimationController _floatingController;
  late final AnimationController _planeController;
  late final AnimationController _secondPlaneController;

  late final Animation<double> _logoFadeAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoRotationAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _planeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3900),
    );

    _secondPlaneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4700),
    );

    _logoFadeAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );

    _logoScaleAnimation = Tween<double>(
      begin: 0.68,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    _logoRotationAnimation = Tween<double>(
      begin: -0.045,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _logoController.forward();
    _floatingController.repeat(reverse: true);
    _planeController.repeat();
    _secondPlaneController.repeat();

    Timer(const Duration(milliseconds: 5600), () {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 650),
          pageBuilder: (_, animation, __) => const LoginPage(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _floatingController.dispose();
    _planeController.dispose();
    _secondPlaneController.dispose();
    super.dispose();
  }

  Widget _buildLogo() {
    return FadeTransition(
      opacity: _logoFadeAnimation,
      child: ScaleTransition(
        scale: _logoScaleAnimation,
        child: AnimatedBuilder(
          animation: _logoRotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _logoRotationAnimation.value,
              child: child,
            );
          },
          child: Image.asset(
            'assets/images/easytour_logo2.jpg',
            width: 310,
            height: 310,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildBubble({
    required double size,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildFlyingPlane({
    required AnimationController controller,
    required double top,
    required double size,
    required Color color,
    required bool reverse,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final progress = controller.value;

        final startX = reverse ? screenWidth + 90 : -90.0;
        final endX = reverse ? -90.0 : screenWidth + 90;

        final x = startX + (endX - startX) * progress;
        final wave = math.sin(progress * math.pi * 2) * 18;

        return Positioned(
          top: top + wave,
          left: x,
          child: Transform.rotate(
            angle: reverse ? -0.25 : 0.25,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(reverse ? math.pi : 0),
              child: child,
            ),
          ),
        );
      },
      child: Icon(
        Icons.flight_rounded,
        color: color,
        size: size,
      ),
    );
  }

  Widget _buildFloatingIcon({
    required IconData icon,
    required double top,
    double? left,
    double? right,
    required Color color,
    required double size,
    required double dx,
    required double dy,
    double rotation = 0.0,
  }) {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        final value = _floatingController.value;
        final wave = math.sin(value * math.pi);

        return Positioned(
          top: top + dy * wave,
          left: left == null ? null : left + dx * wave,
          right: right == null ? null : right - dx * wave,
          child: Transform.rotate(
            angle: -rotation + (rotation * 2 * wave),
            child: child,
          ),
        );
      },
      child: Icon(
        icon,
        color: color,
        size: size,
      ),
    );
  }

  Widget _buildTowerOfPisa() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        final value = math.sin(_floatingController.value * math.pi);
        return Positioned(
          bottom: 64 + value * 8,
          left: 34,
          child: Transform.rotate(
            angle: -0.13,
            child: child,
          ),
        );
      },
      child: CustomPaint(
        size: const Size(70, 120),
        painter: _PisaTowerPainter(),
      ),
    );
  }

  Widget _buildEiffelTower() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        final value = math.sin(_floatingController.value * math.pi);
        return Positioned(
          bottom: 54 + value * 9,
          right: 34,
          child: child!,
        );
      },
      child: CustomPaint(
        size: const Size(86, 135),
        painter: _EiffelTowerPainter(),
      ),
    );
  }

  Widget _buildMountains() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: CustomPaint(
        size: const Size(double.infinity, 130),
        painter: _MountainsPainter(),
      ),
    );
  }

  Widget _buildSun() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        final value = math.sin(_floatingController.value * math.pi);
        return Positioned(
          top: 78 + value * 10,
          right: 36,
          child: Transform.rotate(
            angle: value * 0.25,
            child: child,
          ),
        );
      },
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: orange.withOpacity(0.18),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.wb_sunny_rounded,
            color: orange,
            size: 34,
          ),
        ),
      ),
    );
  }

  Widget _buildLoaderDots() {
    return FadeTransition(
      opacity: _logoFadeAnimation,
      child: AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final delay = index * 0.25;
              final value = math.sin(
                (_floatingController.value + delay) * math.pi * 2,
              );

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 9 + value.abs() * 5,
                height: 9 + value.abs() * 5,
                decoration: BoxDecoration(
                  color: index == 1 ? orange : primaryBlue,
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildCenterContent() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogo(),
              const SizedBox(height: 10),
              _buildLoaderDots(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -70,
            child: _buildBubble(
              size: 210,
              color: lightBlue.withOpacity(0.55),
            ),
          ),
          Positioned(
            top: 150,
            right: -60,
            child: _buildBubble(
              size: 150,
              color: softOrange.withOpacity(0.8),
            ),
          ),
          Positioned(
            bottom: 150,
            left: -45,
            child: _buildBubble(
              size: 120,
              color: primaryBlue.withOpacity(0.07),
            ),
          ),
          Positioned(
            bottom: -70,
            right: -60,
            child: _buildBubble(
              size: 190,
              color: orange.withOpacity(0.10),
            ),
          ),

          _buildMountains(),
          _buildSun(),

          _buildFlyingPlane(
            controller: _planeController,
            top: 145,
            size: 48,
            color: primaryBlue.withOpacity(0.88),
            reverse: false,
          ),
          _buildFlyingPlane(
            controller: _secondPlaneController,
            top: 280,
            size: 36,
            color: orange.withOpacity(0.95),
            reverse: true,
          ),

          _buildFloatingIcon(
            icon: Icons.luggage_rounded,
            top: 205,
            left: 34,
            color: orange.withOpacity(0.90),
            size: 38,
            dx: 8,
            dy: 10,
            rotation: 0.09,
          ),
          _buildFloatingIcon(
            icon: Icons.map_rounded,
            top: 380,
            right: 34,
            color: primaryBlue.withOpacity(0.72),
            size: 36,
            dx: 7,
            dy: -9,
            rotation: 0.08,
          ),
          _buildFloatingIcon(
            icon: Icons.location_on_rounded,
            top: 455,
            left: 45,
            color: orange.withOpacity(0.92),
            size: 36,
            dx: 8,
            dy: -8,
            rotation: 0.05,
          ),
          _buildFloatingIcon(
            icon: Icons.camera_alt_rounded,
            top: 92,
            left: 42,
            color: darkBlue.withOpacity(0.45),
            size: 27,
            dx: 6,
            dy: 6,
            rotation: 0.06,
          ),
          _buildFloatingIcon(
            icon: Icons.explore_rounded,
            top: 430,
            right: 52,
            color: darkBlue.withOpacity(0.42),
            size: 29,
            dx: -7,
            dy: 7,
            rotation: 0.06,
          ),

          _buildTowerOfPisa(),
          _buildEiffelTower(),

          _buildCenterContent(),
        ],
      ),
    );
  }
}

class _PisaTowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const blue = Color(0xFF005A8D);
    const orange = Color(0xFFF58A00);

    final bodyPaint = Paint()
      ..color = blue.withOpacity(0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = orange.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFFEAF4FA).withOpacity(0.92)
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.22, 10, size.width * 0.48, size.height - 18),
      const Radius.circular(18),
    );

    canvas.drawRRect(rect, fillPaint);
    canvas.drawRRect(rect, bodyPaint);

    for (int i = 0; i < 5; i++) {
      final y = 24.0 + i * 18;
      canvas.drawLine(
        Offset(size.width * 0.26, y),
        Offset(size.width * 0.66, y),
        accentPaint,
      );

      canvas.drawCircle(
        Offset(size.width * 0.36, y + 8),
        3,
        bodyPaint..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(size.width * 0.52, y + 8),
        3,
        bodyPaint..style = PaintingStyle.fill,
      );

      bodyPaint.style = PaintingStyle.stroke;
    }

    canvas.drawLine(
      Offset(size.width * 0.14, size.height - 6),
      Offset(size.width * 0.80, size.height - 6),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EiffelTowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const blue = Color(0xFF003F63);
    const orange = Color(0xFFF58A00);

    final towerPaint = Paint()
      ..color = blue.withOpacity(0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = orange.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final top = Offset(size.width / 2, 8);
    final leftBase = Offset(size.width * 0.16, size.height - 6);
    final rightBase = Offset(size.width * 0.84, size.height - 6);

    canvas.drawLine(top, leftBase, towerPaint);
    canvas.drawLine(top, rightBase, towerPaint);

    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.42),
      Offset(size.width * 0.66, size.height * 0.42),
      accentPaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.68),
      Offset(size.width * 0.75, size.height * 0.68),
      accentPaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.26),
      Offset(size.width * 0.62, size.height * 0.68),
      towerPaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.62, size.height * 0.26),
      Offset(size.width * 0.38, size.height * 0.68),
      towerPaint,
    );

    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.24,
        size.height * 0.62,
        size.width * 0.52,
        size.height * 0.28,
      ),
      math.pi,
      math.pi,
      false,
      towerPaint,
    );

    canvas.drawCircle(top, 4, Paint()..color = orange);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MountainsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mountainPaint = Paint()
      ..color = const Color(0xFFEAF4FA)
      ..style = PaintingStyle.fill;

    final mountainPaint2 = Paint()
      ..color = const Color(0xFFFFF2DF)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFF005A8D).withOpacity(0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path1 = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.23, size.height * 0.30)
      ..lineTo(size.width * 0.48, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(size.width * 0.30, size.height)
      ..lineTo(size.width * 0.56, size.height * 0.20)
      ..lineTo(size.width * 0.86, size.height)
      ..close();

    final path3 = Path()
      ..moveTo(size.width * 0.68, size.height)
      ..lineTo(size.width * 0.88, size.height * 0.36)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path1, mountainPaint);
    canvas.drawPath(path2, mountainPaint2);
    canvas.drawPath(path3, mountainPaint);

    canvas.drawPath(path1, linePaint);
    canvas.drawPath(path2, linePaint);
    canvas.drawPath(path3, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}