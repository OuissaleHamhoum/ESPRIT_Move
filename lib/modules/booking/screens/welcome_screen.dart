import 'package:flutter/material.dart';
import '../../../core/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';

/// WEL-01, WEL-02, WEL-03 : 3 pages de bienvenue dans un PageView.
/// Suivant -> page suivante | Passer / Commencer -> inscription.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _pages = [
    ['🏃', 'Bouge avec ton campus', 'Enregistre tes sorties, suis tes progrès et reste motivé.'],
    ['📅', 'Rencontre ton équipe', 'Événements, groupes et défis chaque semaine à ESPRIT.'],
    ['📍', 'Sors en sécurité', 'Réserve les terrains, partage ta position (3 contacts max).'],
  ];

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goSignUp() => Navigator.pushReplacementNamed(context, AppRoutes.signUp);

  void _next() {
    if (_page == _pages.length - 1) {
      _goSignUp();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_pages[i][0], style: const TextStyle(fontSize: 96)),
                      const SizedBox(height: 24),
                      Text(_pages[i][1],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      Text(_pages[i][2],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
            // Points indicateurs
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  Container(
                    margin: const EdgeInsets.all(4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.red : AppColors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                AppButton(label: last ? 'Commencer' : 'Suivant', onPressed: _next),
                TextButton(onPressed: _goSignUp, child: const Text('Passer')),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
