import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import 'screens/admin_users_screen.dart';
import 'screens/beacon_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/chat_rooms_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';

/// MODULE 2 : Utilisateurs, profil, chat - ce que le module expose.
class UsersRoutes {
  static Map<String, WidgetBuilder> get routes => {
        AppRoutes.signIn: (_) => const SignInScreen(),
        AppRoutes.signUp: (_) => const SignUpScreen(),
        AppRoutes.editProfile: (_) => const EditProfileScreen(),
        AppRoutes.changePassword: (_) => const ChangePasswordScreen(),
        AppRoutes.beacon: (_) => const BeaconScreen(),
        AppRoutes.chatRooms: (_) => const ChatRoomsScreen(),
      };

  /// Contenu de l'onglet "Profil" (utilise par MainShell)
  static Widget get profileTab => const ProfileScreen();

  /// Onglet "Comptes" de l'espace administrateur (utilise par AdminShell)
  static Widget get adminUsersTab => const AdminUsersScreen();
}
