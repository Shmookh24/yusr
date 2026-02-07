import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../src/theme/app_theme.dart';
import '../../src/ui/screens/login_screen.dart';
import '../../src/ui/screens/products_screen.dart';
import '../../src/services/session_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation1;
  late Animation<double> _rotationAnimation2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _rotationAnimation1 =
        Tween<double>(begin: 0.0, end: -5.0 * math.pi / 180).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _rotationAnimation2 =
        Tween<double>(begin: 0.0, end: 5.0 * math.pi / 180).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();

    _checkSession();
  }

  Future<void> _checkSession() async {
    // انتظار انتهاء الأنيميشن
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    // التحقق من وجود جلسة محفوظة
    final isLoggedIn = await SessionManager.isLoggedIn();
    final userId = await SessionManager.getUserId();

    if (isLoggedIn && userId != null) {
      // تسجيل الدخول التلقائي
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ProductsScreen(userId: userId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else {
      // الانتقال إلى صفحة تسجيل الدخول
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Square 1 - Blue with text (Left)
              AnimatedBuilder(
                animation: _rotationAnimation1,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation1.value,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text(
                          'يُسر',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                            fontFamily: 'IBMPlexSansArabic',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              // Square 2 - White with black dots pattern (Right)
              AnimatedBuilder(
                animation: _rotationAnimation2,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation2.value,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CustomPaint(
                        painter: DotsPatternPainter(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom painter for dots pattern - 3 rows with varying sizes
class DotsPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLarge = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final paintSmall = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Create 3 rows with varying dot sizes
    // Pattern: large, small, large, small, large (alternating)
    const double largeRadius = 3.5;
    const double smallRadius = 2.0;
    const double rowSpacing = 18.0; // Vertical spacing between rows
    const double colSpacing = 16.0; // Horizontal spacing between dots
    const int rows = 3;
    const int cols = 5;

    // Calculate center position
    final double totalWidth = (cols - 1) * colSpacing;
    final double totalHeight = (rows - 1) * rowSpacing;
    final double startX = (size.width - totalWidth) / 2;
    final double startY = (size.height - totalHeight) / 2;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final x = startX + (col * colSpacing);
        final y = startY + (row * rowSpacing);

        // Alternate pattern: large, small, large, small, large
        final bool isLarge = col % 2 == 0;
        final double radius = isLarge ? largeRadius : smallRadius;
        final Paint paint = isLarge ? paintLarge : paintSmall;

        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
