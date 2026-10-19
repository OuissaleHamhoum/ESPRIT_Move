import 'package:flutter/material.dart';
import '../core/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../modules/activities/activities_routes.dart';
import '../modules/booking/booking_routes.dart';
import '../modules/challenges/challenges_routes.dart';
import '../modules/events/events_routes.dart';
import '../modules/users/users_routes.dart';
import 'main_shell.dart';
import 'unknown_route_screen.dart';

/// Application complete (apres integration des 5 modules).
/// Toutes les routes de tous les modules sont fusionnees ici.
class EspritMoveApp extends StatelessWidget {
  const EspritMoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Ecoute le ThemeController : le changement clair/sombre est immediat.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'ESPRIT Move',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        initialRoute: AppRoutes.splash, // le splash vient du module 4
        routes: {
          AppRoutes.main: (_) => const MainShell(),
          ...BookingRoutes.routes, //    Module 4 (inclut splash + welcome)
          ...UsersRoutes.routes, //      Module 2
          ...ActivitiesRoutes.routes, // Module 1
          ...EventsRoutes.routes, //     Module 3
          ...ChallengesRoutes.routes, // Module 5
        },
        onUnknownRoute: (s) => MaterialPageRoute(
            builder: (_) => UnknownRouteScreen(routeName: s.name)),
      ),
    );
  }
}
