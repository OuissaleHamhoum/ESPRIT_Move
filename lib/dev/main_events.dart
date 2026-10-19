// MEMBRE 3 : flutter run -t lib/dev/main_events.dart
import '../core/app_routes.dart';
import '../modules/events/events_routes.dart';
import 'dev_runner.dart';

void main() => runModule(
      routes: {
        ...EventsRoutes.routes,
        // En solo, la "coque principale" est simplement l'onglet Evenements :
        AppRoutes.main: (_) => EventsRoutes.tab,
      },
      initialRoute: AppRoutes.main,
    );
