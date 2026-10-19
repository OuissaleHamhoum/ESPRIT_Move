import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import 'screens/badge_form_screen.dart';
import 'screens/challenge_form_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/rewards_screen.dart';

/// MODULE 5 : Defis, badges, recompenses, accueil - ce que le module expose.
class ChallengesRoutes {
  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.notifications: (_) => const NotificationsScreen(),
        AppRoutes.rewards: (_) => const RewardsScreen(),
        AppRoutes.dashboard: (_) => const DashboardScreen(),
        AppRoutes.challenges: (_) => const ChallengesScreen(),
        AppRoutes.challengeForm: (_) => const ChallengeFormScreen(),
        AppRoutes.badgeForm: (_) => const BadgeFormScreen(),
      };

  /// Contenu de l'onglet "Accueil" (utilise par MainShell)
  static Widget get homeTab => const HomeScreen();
}
