import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/session/session.dart';
import 'tracking/draft_recovery.dart';
import 'screens/activities_list_screen.dart';
import 'screens/rec_choose_screen.dart';

/// MODULE 1 : Activites - ce que le module "expose" au reste de l'application.
///
/// Les autres ecrans (detail, modification, direct, recap) sont ouverts avec
/// Navigator.push depuis les ecrans ci-dessous : ils ont besoin de parametres.
class ActivitiesRoutes {
  /// Routes nommees fusionnees dans app.dart
  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.recChoose: (_) => const RecChooseScreen(),
      };

  /// Contenu de l'onglet "Activites" (utilise par MainShell)
  static Widget get tab => const ActivitiesListScreen();

  /// Au demarrage (MainShell) : propose de reprendre une sortie interrompue.
  static Future<void> onAppStart(BuildContext context) async {
    if (!Session.isGuest) await DraftRecovery.check(context);
  }
}
