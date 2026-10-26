import 'package:flutter/material.dart';
import '../core/session/session.dart';
import '../modules/booking/booking_routes.dart';
import '../modules/challenges/challenges_routes.dart';
import '../modules/users/users_routes.dart';
import '../core/widgets/empty_state.dart';

/// Espace ADMINISTRATEUR : barre d'onglets separee de celle des etudiants.
///   Accueil | Terrains | Reservations | Comptes
/// Un etudiant ne peut pas l'ouvrir (garde ci-dessous).
/// Argument optionnel de la route : index de l'onglet a ouvrir (int).
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  bool _argRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argRead) return;
    _argRead = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is int && arg >= 0 && arg < 4) _index = arg;
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.isAdmin) return const AdminOnlyScreen();

    // Pas de IndexedStack : chaque onglet recharge ses donnees a l'affichage.
    final pages = <Widget>[
      ChallengesRoutes.adminHomeTab, // Module 5
      BookingRoutes.adminFacilitiesTab, // Module 4
      BookingRoutes.adminBookingsTab, // Module 4
      UsersRoutes.adminUsersTab, // Module 2
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.stadium_outlined), label: 'Terrains'),
          NavigationDestination(icon: Icon(Icons.event_available_outlined), label: 'Réservations'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Comptes'),
        ],
      ),
    );
  }
}

/// Affiche a la place d'un ecran admin quand l'utilisateur n'est pas admin.
class AdminOnlyScreen extends StatelessWidget {
  const AdminOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Accès refusé')),
        body: const EmptyState(
            emoji: '🔒', message: 'Cet écran est réservé à l’administration.'),
      );
}
