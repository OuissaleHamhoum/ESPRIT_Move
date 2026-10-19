# ESPRIT Move

Application Flutter (SQLite local) : activités, profil & chat, événements, réservation, défis & badges.

➡️ Tout est expliqué dans **[GUIDE.md](GUIDE.md)** (architecture, répartition, installation, base de données, intégration).

Démarrage rapide :
```bash
flutter create --org tn.esprit --project-name esprit_move .
# Windows : activer le "Mode développeur" (start ms-settings:developers), sinon les plugins ne compilent pas
# puis supprimer test/widget_test.dart (généré, inutile ici)
flutter pub get
flutter run -t lib/dev/main_activities.dart   # ou main_users / main_events / main_booking / main_challenges
flutter run                                    # application complète
```
Comptes de test : `mariem@esprit.tn / 123456` · `admin@esprit.tn / admin123`
