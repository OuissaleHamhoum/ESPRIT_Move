// MEMBRE 5 : flutter run -t lib/dev/main_challenges.dart
// loginAsUserId: 2 -> administrateur (pour tester + Defi, + Badge, dashboard).
import '../core/app_routes.dart';
import '../modules/challenges/challenges_routes.dart';
import 'dev_runner.dart';

void main() => runModule(
      routes: {
        ...ChallengesRoutes.routes,
        // En solo, la "coque principale" est simplement l'onglet Accueil :
        AppRoutes.main: (_) => ChallengesRoutes.homeTab,
      },
      initialRoute: AppRoutes.main,
      loginAsUserId: 1,
    );
