import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import 'screens/event_form_screen.dart';
import 'screens/events_screen.dart';
import 'screens/groups_screen.dart';

/// MODULE 3 : Evenements et groupes - ce que le module expose.
class EventsRoutes {
  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.groups: (_) => const GroupsScreen(),
        AppRoutes.eventForm: (_) => const EventFormScreen(),
        AppRoutes.adminEvents: (_) => const EventsScreen(),
      };

  /// Contenu de l'onglet "Evenements" (utilise par MainShell)
  static Widget get tab => const EventsScreen();
}
