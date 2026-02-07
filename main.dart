import 'package:flutter/material.dart';
import 'src/theme/app_theme.dart';
import 'ui/screens/splash_screen.dart';
import 'src/ui/screens/register_screen.dart';

void main() {
  runApp(const YusrApp());
}

class YusrApp extends StatelessWidget {
  const YusrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'يُسر',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const SplashScreen(),
      routes: {
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}
