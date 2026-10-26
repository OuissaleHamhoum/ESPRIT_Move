import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import 'screens/admin_bookings_screen.dart';
import 'screens/admin_facilities_screen.dart';
import 'screens/facilities_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';

/// MODULE 4 : Reservation + ecrans de lancement - ce que le module expose.
class BookingRoutes {
  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.welcome: (_) => const WelcomeScreen(),
        AppRoutes.booking: (_) => const FacilitiesScreen(),
      };

  /// Onglets de l'espace administrateur (utilises par AdminShell)
  static Widget get adminFacilitiesTab => const AdminFacilitiesScreen();
  static Widget get adminBookingsTab => const AdminBookingsScreen();
}
