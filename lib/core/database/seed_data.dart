import 'package:sqflite/sqflite.dart';
import '../utils/security.dart';

/// Donnees de DEPART inserees a la creation de la base.
/// Aucune donnee de demonstration : seulement ce dont l'application a besoin
/// pour fonctionner. Tout le reste (terrains, evenements, defis,
/// recompenses...) est cree par l'administration et les etudiants.
///
/// COMPTE ADMINISTRATEUR INITIAL (a changer apres la premiere connexion) :
///   admin@esprit.tn / admin123
class SeedData {
  static const adminEmail = 'admin@esprit.tn';
  static const adminInitialPassword = 'admin123';

  static Future<void> run(Database db) async {
    final now = DateTime.now().toIso8601String();

    // ---- Administrateur (gere terrains, reservations, comptes, defis) ----
    await db.insert('users', {
      'name': 'Administration ESPRIT',
      'email': adminEmail,
      'password_hash': Security.hash(adminInitialPassword),
      'card_verified': 1,
      'role': 'admin',
      'created_at': now,
    });

    // ---- Salons de chat (vides) ----
    for (final r in [
      ['Général campus', '💬'],
      ['Running', '🏃'],
      ['Football', '⚽'],
      ['Basket', '🏀'],
      ['Padel', '🎾'],
    ]) {
      await db.insert('rooms', {'name': r[0], 'icon': r[1]});
    }

    // ---- Groupes du campus (aucun membre au depart) ----
    for (final g in [
      ['Running Club', '🏃'],
      ['Basket ESPRIT', '🏀'],
      ['Yoga & Bien-être', '🧘'],
      ['Foot Campus', '⚽'],
      ['Padel ESPRIT', '🎾'],
      ['Cyclistes', '🚴'],
    ]) {
      await db.insert('campus_groups', {'name': g[0], 'icon': g[1]});
    }

    // ---- Regles des badges (attribues automatiquement, voir RewardEngine) ----
    await db.insert('badges',
        {'name': 'Premier 10K', 'icon': '🥇', 'rule': 'distance', 'threshold': 10});
    await db.insert('badges',
        {'name': 'Régulier', 'icon': '🔥', 'rule': 'activities', 'threshold': 3});
    await db.insert('badges',
        {'name': 'Esprit d’équipe', 'icon': '🤝', 'rule': 'events', 'threshold': 20});
  }
}
