// MEMBRE 4 : flutter run -t lib/dev/main_booking.dart
// Pour tester le lancement (splash + bienvenue) : initialRoute: AppRoutes.splash
import '../core/app_routes.dart';
import '../modules/booking/booking_routes.dart';
import 'dev_runner.dart';

void main() => runModule(
      routes: BookingRoutes.routes,
      initialRoute: AppRoutes.booking,
    );
