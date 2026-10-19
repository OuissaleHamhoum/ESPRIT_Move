import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';

/// SPL-01 : logo, puis apres 1,7 s -> bienvenue (ou accueil si deja connecte).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      final next = Session.isGuest ? AppRoutes.welcome : AppRoutes.main;
      Navigator.pushReplacementNamed(context, next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.red, borderRadius: BorderRadius.circular(20)),
              alignment: Alignment.center,
              child: const Text('E',
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            const Text.rich(TextSpan(
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: 'ESPRIT '),
                  TextSpan(text: 'Move', style: TextStyle(color: AppColors.red)),
                ])),
            const SizedBox(height: 6),
            Text('Bouge. Rencontre. Progresse.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
