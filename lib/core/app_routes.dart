/// ============================================================
///  NOMS DES ROUTES (contrat commun a toute l'equipe)
/// ============================================================
/// Un seul fichier pour que les 5 modules puissent s'appeler entre eux
/// SANS importer les ecrans des autres. Exemple :
///   Navigator.pushNamed(context, AppRoutes.challenges);
/// Si la route n'existe pas encore (module d'un collegue pas fini),
/// un ecran "non integre" s'affiche : rien ne plante.
class AppRoutes {
  // --- Lancement (Module 4) ---
  static const splash = '/';
  static const welcome = '/welcome';

  // --- Coque principale : barre d'onglets (commun) ---
  static const main = '/main'; // argument optionnel : index d'onglet (int)

  // --- Module 2 : Utilisateurs, profil, chat ---
  static const signIn = '/signin';
  static const signUp = '/signup';
  static const editProfile = '/profile/edit';
  static const beacon = '/beacon';
  static const chatRooms = '/chat';

  // --- Module 1 : Activites ---
  static const recChoose = '/rec/choose';

  // --- Module 3 : Evenements et groupes ---
  static const groups = '/groups';
  static const eventForm = '/events/form';

  // --- Module 4 : Reservation ---
  static const booking = '/booking';

  // --- Module 5 : Defis, badges, accueil ---
  static const notifications = '/notifications';
  static const rewards = '/rewards';
  static const dashboard = '/dashboard';
  static const challenges = '/challenges';
  static const challengeForm = '/challenges/form';
  static const badgeForm = '/badges/new';
}
