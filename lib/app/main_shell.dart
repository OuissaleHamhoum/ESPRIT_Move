import 'package:flutter/material.dart';
import '../core/app_routes.dart';
import '../core/theme/app_colors.dart';
import '../modules/activities/activities_routes.dart';
import '../modules/challenges/challenges_routes.dart';
import '../modules/events/events_routes.dart';
import '../modules/users/users_routes.dart';

/// Barre d'onglets principale (PDF section 3) :
///   Accueil | Activites | [ bouton rouge REC ] | Evenements | Profil
///
/// Chaque onglet est fourni par UN module (voir *_routes.dart).
/// Argument optionnel de la route : index de l'onglet a ouvrir (int).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _argRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argRead) return;
    _argRead = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is int) _index = arg;
  }

  @override
  Widget build(BuildContext context) {
    // Pas de IndexedStack : l'onglet est reconstruit a chaque changement,
    // donc ses donnees SQLite sont rechargees (liste toujours a jour).
    final pages = <Widget>[
      ChallengesRoutes.homeTab, // Module 5
      ActivitiesRoutes.tab, // Module 1
      EventsRoutes.tab, // Module 3
      UsersRoutes.profileTab, // Module 2
    ];

    return Scaffold(
      body: pages[_index],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 60,
        height: 60,
        child: FloatingActionButton(
          backgroundColor: AppColors.red,
          shape: const CircleBorder(),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.recChoose),
          child: const Icon(Icons.fiber_manual_record, color: Colors.white, size: 30),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _item(0, Icons.home_outlined, 'Accueil'),
            _item(1, Icons.directions_run, 'Activités'),
            const SizedBox(width: 56), // place du bouton central
            _item(2, Icons.event_outlined, 'Événements'),
            _item(3, Icons.person_outline, 'Profil'),
          ],
        ),
      ),
    );
  }

  Widget _item(int i, IconData icon, String label) {
    final on = _index == i;
    final color = on ? AppColors.red : AppColors.grey;
    return InkWell(
      onTap: () => setState(() => _index = i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
