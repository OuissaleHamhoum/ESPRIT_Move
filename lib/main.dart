import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/database/app_database.dart';
import 'core/session/session.dart';
import 'core/theme/app_theme.dart';

/// Point d'entree de l'application complete.
/// Chaque membre travaille avec SON fichier dans lib/dev/ (voir GUIDE.md).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.db; //        1. ouvre / cree la base SQLite
  await ThemeController.load(); // 2. theme clair ou sombre memorise
  await Session.restore(); //      3. retrouve l'utilisateur connecte
  runApp(const EspritMoveApp());
}
