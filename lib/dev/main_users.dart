// MEMBRE 2 : flutter run -t lib/dev/main_users.dart
// Pour tester l'inscription / connexion : initialRoute: AppRoutes.signUp
// et loginAsUserId: 0 (visiteur).
import '../core/app_routes.dart';
import '../modules/users/users_routes.dart';
import 'dev_runner.dart';

void main() => runModule(
      routes: {
        ...UsersRoutes.routes,
        // En solo, la "coque principale" est simplement l'onglet Profil :
        AppRoutes.main: (_) => UsersRoutes.profileTab,
      },
      initialRoute: AppRoutes.main,
      loginAsUserId: 1,
    );
