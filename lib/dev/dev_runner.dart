import 'package:flutter/material.dart';
import '../app/unknown_route_screen.dart';
import '../core/database/app_database.dart';
import '../core/session/session.dart';
import '../core/theme/app_theme.dart';

/// Lanceur pour travailler SUR UN SEUL MODULE (pas besoin des 4 autres).
///
///   - ouvre la meme base SQLite avec les memes donnees de demo
///   - connecte automatiquement un utilisateur de test
///   - les routes des autres modules affichent un ecran "non integre"
///
/// Exemple : flutter run -t lib/dev/main_activities.dart
Future<void> runModule({
  required Map<String, WidgetBuilder> routes,
  required String initialRoute,
  int loginAsUserId = 1, // 1 = etudiante Mariem, 2 = admin, 0 = visiteur
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.db;
  await ThemeController.load();
  if (loginAsUserId > 0) await Session.devLogin(loginAsUserId);

  runApp(ValueListenableBuilder<ThemeMode>(
    valueListenable: ThemeController.mode,
    builder: (context, mode, _) => MaterialApp(
      title: 'ESPRIT Move (dev)',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      initialRoute: initialRoute,
      routes: routes,
      onUnknownRoute: (s) => MaterialPageRoute(
          builder: (_) => UnknownRouteScreen(routeName: s.name)),
    ),
  ));
}
