import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

/// Utilisateur actuellement connecte. C'est le "jeton de connexion" du PDF :
/// tous les modules lisent Session.userId pour savoir QUI est connecte.
///
///   Session.userId   -> int? (null = visiteur sans compte)
///   Session.isGuest  -> true si pas connecte
///   Session.isAdmin  -> true si role admin
///
/// Seul le module 2 (Users) appelle login() / logout().
class Session {
  static int? userId;
  static String name = '';
  static String role = 'student';

  static bool get isGuest => userId == null;
  static bool get isAdmin => role == 'admin';

  /// Memorise l'utilisateur (reste connecte apres fermeture de l'app).
  static Future<void> login(
      {required int id, required String name, required String role}) async {
    userId = id;
    Session.name = name;
    Session.role = role;
    final db = await AppDatabase.db;
    final rows = await db.query('users',
        columns: ['email'], where: 'id = ?', whereArgs: [id]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', id);
    // L'e-mail sert de verification : si la base est recreee, un ancien id
    // ne doit jamais reconnecter quelqu'un d'autre (ex. l'admin).
    if (rows.isNotEmpty) await prefs.setString('user_email', rows.first['email'] as String);
  }

  static Future<void> logout() async {
    userId = null;
    name = '';
    role = 'student';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
  }

  /// Au demarrage : retrouve l'utilisateur memorise (si le compte existe
  /// encore ET correspond au meme e-mail).
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');
    if (id == null) return;
    final email = prefs.getString('user_email');
    if (email == null || !await _load(id, email: email)) await logout();
  }

  /// Developpement isole : se connecte directement sans ecran de login.
  /// 1 = administrateur initial (voir seed_data.dart).
  static Future<void> devLogin(int id) async => _load(id);

  static Future<bool> _load(int id, {String? email}) async {
    final db = await AppDatabase.db;
    final rows = await db.query('users',
        columns: ['id', 'name', 'role', 'email'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return false;
    if (email != null && rows.first['email'] != email) return false;
    userId = id;
    name = rows.first['name'] as String;
    role = rows.first['role'] as String;
    return true;
  }
}
