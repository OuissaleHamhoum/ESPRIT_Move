# ESPRIT Move : guide d'équipe (Flutter + SQLite local)

Application mobile de sport communautaire du campus ESPRIT. 5 membres, 5 modules, **une seule base SQLite locale sur le téléphone** (pas de serveur, pas d'internet).

> ⚠️ **À lire d'abord.** Ce code a été écrit sans pouvoir le compiler (pas de Flutter dans l'environnement de génération). Il est volontairement simple, mais **lancez `flutter analyze` dès l'étape 1** : s'il reste une petite erreur (version de package, nom d'API), elle se corrige en une ligne. Corrigez-la une seule fois, puis partagez la correction avec le groupe.

---

## 1. Pourquoi SQLite et pas Hive ?

| | SQLite (`sqflite`) ✅ choisi | Hive |
|---|---|---|
| Type | Base relationnelle (tables, SQL) | Base clé/valeur (boîtes) |
| Relations | Oui : un utilisateur a des activités, des réservations... | À gérer à la main |
| Classement, statistiques | `SUM`, `COUNT`, `JOIN` en une requête | Boucles Dart |
| Suppression de compte | `ON DELETE CASCADE` supprime tout | Supprimer boîte par boîte |

Le projet a beaucoup de liens entre modules (activités → défis → badges → points), donc SQL est plus simple et plus sûr. Hive reste un bon choix pour un projet avec des données isolées.

---

## 2. Architecture

Même esprit que vos workshops (`models/`, `screens/`, `widgets/`, routes nommées dans `main.dart`, `Form` + `GlobalKey`, `Navigator`), mais **rangé par module** pour que 5 personnes ne se marchent pas dessus.

```
lib/
├── main.dart                    ← point d'entrée (app complète)
├── app/                         ← ASSEMBLAGE (chef d'équipe)
│   ├── app.dart                 ← MaterialApp + fusion des routes des 5 modules
│   ├── main_shell.dart          ← barre d'onglets + bouton rouge central
│   └── unknown_route_screen.dart← écran "module pas encore intégré"
├── core/                        ← BASE COMMUNE (étape 0, ne pas casser)
│   ├── app_routes.dart          ← noms des routes (contrat entre modules)
│   ├── database/
│   │   ├── app_database.dart    ← ouvre la base SQLite
│   │   ├── schema.dart          ← TOUTES les tables (une section par module)
│   │   └── seed_data.dart       ← données de démo + comptes de test
│   ├── session/session.dart     ← utilisateur connecté (Session.userId)
│   ├── services/reward_engine.dart ← points + badges (règles partagées)
│   ├── theme/                   ← couleurs, thème clair/sombre
│   ├── utils/                   ← format.dart (dates), security.dart (hash)
│   └── widgets/                 ← boutons, champs, dialogues... communs
├── modules/
│   ├── activities/   (Membre 1)
│   ├── users/        (Membre 2)
│   ├── events/       (Membre 3)
│   ├── booking/      (Membre 4)
│   └── challenges/   (Membre 5)
│       ├── models/              ← classes Dart (Activity, AppUser...)
│       ├── data/                ← DAO : le SEUL endroit où on écrit du SQL
│       ├── screens/             ← écrans
│       ├── widgets/             ← petits composants du module
│       └── <module>_routes.dart ← ce que le module "expose" aux autres
└── dev/
    ├── dev_runner.dart          ← lanceur pour travailler seul
    └── main_<module>.dart       ← 1 point d'entrée par membre
```

**Principe en 3 couches (identique dans chaque module) :**

```
Écran (screens/)  →  DAO (data/)  →  SQLite
 affiche, valide     écrit le SQL     fichier esprit_move.db
```
Un écran n'écrit **jamais** de SQL. Il appelle `ActivityDao.insert(...)`, etc.

---

## 3. Répartition du travail

| Membre | Module | Dossier | Tables SQLite | Point d'entrée solo |
|---|---|---|---|---|
| **1** | Activités | `modules/activities` | `activities` | `lib/dev/main_activities.dart` |
| **2** | Utilisateurs, profil, chat | `modules/users` | `users`, `beacon_contacts`, `rooms`, `messages` | `lib/dev/main_users.dart` |
| **3** | Événements et groupes | `modules/events` | `events`, `event_participants`, `campus_groups`, `group_members` | `lib/dev/main_events.dart` |
| **4** | Réservation + lancement | `modules/booking` | `facilities`, `bookings` | `lib/dev/main_booking.dart` |
| **5** | Défis, badges, accueil | `modules/challenges` | `challenges`, `challenge_participants`, `badges`, `user_badges`, `rewards` | `lib/dev/main_challenges.dart` |

Tables communes (modules 3 et 4) : `places`.

### Qui fait quoi, par écran (IDs du PDF → fichiers)

| ID | Fichier |
|---|---|
| SPL-01 / WEL-01..03 | `booking/screens/splash_screen.dart`, `welcome_screen.dart` |
| SU-01..SU-06 | `users/screens/sign_up_screen.dart` (5 étapes + succès dans un seul écran) |
| *(ajouté)* Connexion | `users/screens/sign_in_screen.dart` (absent du PDF, indispensable) |
| PRO-01 / PRO-04 | `users/screens/profile_screen.dart` (suppression = feuille de confirmation) |
| PRO-02 / PRO-03 | `edit_profile_screen.dart` / `beacon_screen.dart` |
| CHAT-01 / CHAT-02 | `chat_rooms_screen.dart` / `chat_room_screen.dart` |
| REC-01 | `activities/screens/rec_choose_screen.dart` |
| REC-02, 03, 04 | `rec_live_screen.dart` (3 états d'un même écran) |
| REC-05 | `rec_summary_screen.dart` |
| ACT-01 / ACT-05 | `activities_list_screen.dart` (liste + état vide) |
| ACT-02 / ACT-03 / ACT-04 | `activity_detail_screen.dart` / `activity_edit_screen.dart` / confirmation |
| GRP-01 | `events/screens/groups_screen.dart` |
| EV-01 / EV-02 | `events_screen.dart` (bouton Liste / Carte) |
| EV-03 / EV-04 / EV-05 / EV-06 | `event_detail_screen.dart` / `event_form_screen.dart` / confirmation / `GuestGate` |
| BK-01 | `booking/screens/facilities_screen.dart` |
| BK-02 / BK-04 | `slot_picker_screen.dart` (réserver / changer) |
| BK-03 / BK-05 / BK-06 | notification / confirmation / `GuestGate` |
| HOME-01 | `challenges/screens/home_screen.dart` |
| NOTIF-01 / REW-01 / DASH-01 | `notifications_screen.dart` / `rewards_screen.dart` / `dashboard_screen.dart` |
| CH-01 / BDG-01 | `challenges_screen.dart` (défis + grille de badges) |
| CH-02 / CH-03 | `leaderboard_screen.dart` / `challenge_form_screen.dart` |
| BDG-02 / BDG-03 | `certificate_screen.dart` / `badge_form_screen.dart` |

Les maquettes (dossiers `claire` / `sombre`) servent de référence visuelle. Le thème gère les deux modes ; le bouton « Thème clair / sombre » est dans le profil.

---

## 4. Installation (chaque membre, sur son PC)

```bash
# 1. Dans le dossier du projet : générer les dossiers android/ ios/ manquants
flutter create --org tn.esprit --project-name esprit_move .
# Windows : activer le "Mode développeur" (start ms-settings:developers), sinon les plugins ne compilent pas
# puis supprimer test/widget_test.dart (généré, inutile ici)

# 2. Télécharger les packages
flutter pub get

# 3. Vérifier qu'il n'y a pas d'erreur
flutter analyze
```

### Tester sur PC Windows (sans téléphone)
`flutter run -d windows` (le Mode développeur Windows doit être activé). **Pas Chrome/Edge** : SQLite ne marche pas sur le web (page blanche).

### Lancer sur un téléphone Android
1. Téléphone : *Paramètres → À propos → toucher 7 fois « Numéro de build »* puis *Options développeur → Débogage USB*.
2. Brancher en USB, accepter la fenêtre d'autorisation.
3. `flutter devices` (le téléphone doit apparaître), puis :

```bash
flutter run -t lib/dev/main_activities.dart     # Membre 1 (adaptez selon votre module)
flutter run                                      # application complète (après intégration)
```
Un émulateur Android Studio fonctionne pareil.

> Android : si une erreur parle de `minSdkVersion`, mettre `minSdk = 21` dans `android/app/build.gradle(.kts)`.

---

## 5. Connexion à la base de données locale (téléphone)

### Comment ça marche
- Au premier lancement, `AppDatabase.db` crée le fichier **`esprit_move.db`** dans le stockage privé de l'application, exécute `schema.dart` (création des tables) puis `seed_data.dart` (données de démo).
- Ensuite, chaque DAO fait `final db = await AppDatabase.db;` et utilise `db.insert / query / update / delete`.
- **Rien à installer ni configurer** : pas de serveur, pas d'IP, pas d'internet. Les données restent sur le téléphone.
- Chaque téléphone a **sa propre base**. Deux membres ne partagent pas leurs données : c'est normal pour ce projet.

### Comptes de test (créés automatiquement)
| Rôle | E-mail | Mot de passe | id |
|---|---|---|---|
| Étudiante | `mariem@esprit.tn` | `123456` | 1 |
| Administrateur | `admin@esprit.tn` | `admin123` | 2 |

En mode solo (`lib/dev/`), vous êtes connecté automatiquement (`loginAsUserId`). `0` = visiteur sans compte.

### Le patron CRUD (à copier pour toute nouvelle fonction)
Exemple réel du module 1 :

```dart
// 1. models/activity.dart : la classe + toMap() / fromMap()
// 2. data/activity_dao.dart : le SQL
static Future<int> insert(Activity a) async {
  final db = await AppDatabase.db;
  return db.insert('activities', a.toMap());           // CREATE
}
static Future<List<Activity>> getByUser(int userId) async {
  final db = await AppDatabase.db;
  final rows = await db.query('activities',
      where: 'user_id = ?', whereArgs: [userId], orderBy: 'date DESC');
  return rows.map(Activity.fromMap).toList();           // READ
}
// update → db.update(...)    delete → db.delete(...)

// 3. screens/ : l'écran appelle le DAO puis rafraîchit
Future<void> _load() async {
  final list = await ActivityDao.getByUser(Session.userId!);
  setState(() => _activities = list);
}
```
Règles : toujours `whereArgs: [...]` (jamais de texte collé dans le SQL), toujours `if (!mounted) return;` après un `await` avant d'utiliser `context`.

### Voir le contenu de la base
- **Android Studio** : *View → Tool Windows → App Inspection → Database Inspector* (app en cours d'exécution). On voit les tables et on peut lancer des requêtes SQL.
- Ou en ligne de commande (app en debug) :
  `adb exec-out run-as tn.esprit.esprit_move cat databases/esprit_move.db > esprit_move.db` puis ouvrir avec *DB Browser for SQLite*.

### Repartir d'une base neuve
- Désinstaller l'application du téléphone, **ou** appeler une fois `await AppDatabase.reset();`
- Si vous changez le schéma : modifier `schema.dart`, passer `dbVersion` de 1 à 2 dans `app_database.dart` (la base est alors recréée avec les données de démo).

---

## 6. Règles d'équipe

1. **Étape 0 (ensemble, 1 h)** : le chef d'équipe crée le dépôt Git avec ce projet tel quel. Chacun le clone, lance `flutter pub get` et son point d'entrée `lib/dev/main_<module>.dart`.
2. **Chacun travaille uniquement dans son dossier `lib/modules/<son_module>/`.** Un dossier = une personne = pas de conflit Git.
3. **Fichiers partagés** (`core/`, `app/`, `schema.dart`, `app_routes.dart`) : on les modifie seulement après accord du groupe, en petit commit séparé. Le schéma SQL est déjà complet pour les 5 modules.
4. Une branche par membre : `git checkout -b module-activities`, puis *pull request* vers `main` quand le module est prêt.
5. Ne jamais importer un écran d'un autre module. Pour aller chez un collègue : `Navigator.pushNamed(context, AppRoutes.xxx)`. Si sa route n'existe pas encore, l'écran « non intégré » s'affiche (pas de plantage).
6. Pour lire les données d'un autre module : lecture seule en SQL dans votre DAO (comme `HomeDao`), ou via `core/services/`.
7. Styles : toujours `AppColors`, `AppButton`, `AppTextField`, `ConfirmSheet`... pas de couleur écrite à la main.

---

## 7. Contrats entre modules

| Besoin | Fournisseur | Utilisation |
|---|---|---|
| Qui est connecté ? | Module 2 → `Session` | `Session.userId`, `Session.isGuest`, `Session.isAdmin` |
| Points / badges après une action | `core/services/reward_engine.dart` | M1 : `onActivityCreated(...)` · M3 : `onEventJoined / onEventLeft` · M2 : `addPoints(id, signupPoints)` |
| Visiteur sans compte | `core/widgets/guest_gate.dart` | `if (!await GuestGate.check(context)) return;` avant toute écriture |
| Lieux du campus | table `places` (M3 et M4) | lecture seule |
| Carte étudiante vérifiée | colonne `users.card_verified` (M2) | M4 la lit avant une réservation |
| Activités → défis | table `activities` (M1) | M5 les compte sur les N derniers jours |

Règles métier déjà codées : titre par défaut « Sport du jour », 8 kcal/min, 10 pts/km, 50 pts/événement, 100 pts/badge, 100 pts à l'inscription, Beacon 3 contacts max (pas d'activation sans contact), « Complet » / « Annulé », créneau pris barré, suppression toujours confirmée, mots de passe hachés (sha256).

---

## 8. Plan de travail et intégration

| Étape | Contenu | Qui |
|---|---|---|
| 0 | Dépôt Git, installation, test des 5 `main_*.dart` | Tous |
| 1 | Chaque module en solo (CRUD complet + états vide/erreur) | Chacun |
| 2 | Revue croisée : chacun relit le DAO d'un collègue | Tous |
| 3 | Intégration : fusion des branches, lancer `flutter run` (app complète) | Chef d'équipe + Membre 5 |
| 4 | Tests des 7 parcours, modes clair/sombre, démo | Tous |

**Intégration** : `app/app.dart` et `main_shell.dart` branchent déjà les 5 modules via `*_routes.dart`. Si chaque module garde son fichier `<module>_routes.dart` avec `routes` et son onglet (`tab`, `profileTab`, `homeTab`), il n'y a **rien à câbler**.

### Liste de contrôle (7 parcours du PDF)
- [ ] 1. Premier lancement : splash → 3 bienvenues → inscription 5 étapes → accueil (+100 pts)
- [ ] 2. Enregistrer une sortie : bouton rouge → GO → 3-2-1 → pause/reprise → terminer → enregistrer → liste → détail
- [ ] 3. Événements : liste ↔ carte → détail → Rejoindre → Quitter (et « Complet »)
- [ ] 4. Réserver un créneau → changer (l'ancien est libéré) → annuler
- [ ] 5. Défi : Participer → Classement → badge → Partager
- [ ] 6. Beacon : 3 contacts → activer (refusé sans contact)
- [ ] 7. Admin (interrupteur dans Profil) : + Défi, + Badge, tableau de bord
- [ ] CRUD de chaque module testé de bout en bout, modes clair et sombre vérifiés

---

## 9. Ce qui est simplifié (prototype) et comment l'améliorer

| Fonction | État actuel | Évolution |
|---|---|---|
| Distance en direct | **Simulée** (vitesse moyenne par sport, mode démo ×30) | Package `geolocator` + permission, calculer la distance entre points GPS |
| Tracé du parcours | Zone réservée | Stocker les points GPS (colonne `route` en JSON) et dessiner avec `CustomPaint` |
| Chat | Un « autre étudiant » répond après 1 s (simulation) | Firebase / WebSocket pour un vrai temps réel entre téléphones |
| Scan de la carte étudiante | Bouton qui simule la vérification | Package `camera` + ML Kit (OCR) |
| Beacon | Active / inactive, aucune position stockée | Envoi de la position aux contacts via un service (SMS / backend) |
| Partager un certificat | Copie le texte dans le presse-papiers | Package `share_plus` |
| Carte des événements | Plan schématique (positions dans `places`) | `google_maps_flutter` ou `flutter_map` |
| Base partagée entre téléphones | Locale à chaque appareil | Backend (Firebase, Supabase) |

---

## 10. Dépannage rapide

| Problème | Solution |
|---|---|
| `no such table` / colonne inconnue | Schéma changé : désinstaller l'app ou `AppDatabase.reset()` |
| `UNIQUE constraint failed: users.email` | E-mail déjà utilisé (normal) |
| Écran « non intégré » | La route appartient à un autre module : attendu en solo |
| `flutter analyze` signale une API | Mettre à jour Flutter (`flutter upgrade`) : le projet vise le SDK `^3.10.0` comme vos workshops |
| Les données ne se rafraîchissent pas | Appeler `_load()` après `await Navigator.push(...)` (déjà fait dans les listes) |
