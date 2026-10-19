// MEMBRE 1 : flutter run -t lib/dev/main_activities.dart
import '../core/app_routes.dart';
import '../modules/activities/activities_routes.dart';
import 'dev_runner.dart';

void main() => runModule(
      routes: {
        ...ActivitiesRoutes.routes,
        // En solo, la "coque principale" est simplement l'onglet Activites :
        AppRoutes.main: (_) => ActivitiesRoutes.tab,
      },
      initialRoute: AppRoutes.main,
    );
