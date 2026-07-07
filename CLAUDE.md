# CLAUDE.md — Smart School Manager (SSM)

## Rôle
Tu es l'assistant de développement du projet SSM.
Travaille TOUJOURS en français. Code complet à chaque fois.
Attends confirmation avant de passer à l'étape suivante.
Terminal = PowerShell uniquement.

## Stack technique
- Backend  : Laravel 13, PHP 8.3, MySQL (DB: ssm_db), Sanctum
- Frontend : Flutter (Windows Desktop + Android + Web), Dart
- PDF      : barryvdh/laravel-dompdf
- Notif.   : WhatsApp via wa.me (JAMAIS d'API payante)
- Offline  : shared_preferences + connectivity_plus

## Chemins importants
- Backend  : D:\smart-school-manager\backend\
- Frontend : D:\smart-school-manager\frontend\ssm_app\lib\
- API URL  : http://127.0.0.1:8000/api (dans app_config.dart)
- PDF views: backend\resources\views\pdf\

## Conventions OBLIGATOIRES
- Tout en français : tables, colonnes, variables, méthodes, classes, UI
- snake_case pour PHP/BDD, camelCase pour Dart, PascalCase pour classes
- Multi-tenancy strict : toujours filtrer par ecole_id = $request->user()->ecole_id
- Marque blanche : Color(int.parse(couleur.replaceAll('#', '0xFF')))
- Pattern headers Flutter :
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

## Pièges Laravel 13 à éviter
- api.php déclaré dans bootstrap/app.php (withRouting)
- CORS: config/cors.php publié, allowed_origins: ['*']
- Schema::defaultStringLength(191) dans AppServiceProvider::boot()
- Index composites = nommer manuellement (ex: 'ecm_unique')

## Tables principales (tout en français)
- ecoles, users (+ecole_id, role, mot_de_passe_change)
- annees_academiques, periodes_academiques
- classes, matieres, enseignant_classe_matiere (pivot)
- eleves (+photo_path, accessor photo_url), inscriptions
- notes (statut: brouillon|soumis|valide|rejete)
- paiements, absences, notifications_attente
- appreciations_bulletins, permissions_modules

## Controllers API existants (app/Http/Controllers/Api/)
Auth/InscriptionEcoleController, Auth/ConnexionController,
UtilisateurController, ClasseController, MatiereController,
AffectationController, AnneeAcademiqueController,
PeriodeAcademiqueController, EleveController, NoteController,
PaiementController, AbsenceController, BulletinController,
AppreciationController, NotificationAttenteController,
StatistiqueController, DashboardController

## Services Flutter existants (lib/services/)
auth_service, utilisateur_service, classe_service, matiere_service,
affectation_service, annee_service, eleve_service, note_service,
paiement_service, absence_service, bulletin_service,
appreciation_service, notification_attente_service,
statistique_service, dashboard_service, sync_service, whatsapp_service

## Routes Flutter (main.dart)
/login, /changer-mot-de-passe, /tableau-de-bord,
/dashboard/enseignant, /dashboard/censeur, /dashboard/secretaire,
/directeur/utilisateurs|classes|matieres|annees|eleves,
/notes/validation, /enseignant/notes|absences,
/paiements, /paiements/renvoi, /profil,
/statistiques, /bulletins, /sync, /notifications

## Tâche en cours
Création des seeders Laravel pour les tests.
Fichiers à remplir dans database/seeders/ :
- EcoleSeeder       → récupère école code 4DTI5X (firstOrCreate)
- ClasseSeeder      → 7 classes (6ème A à Terminale A)
- MatiereSeeder     → 10 matières avec coefficients
- UtilisateurSeeder → censeur + secrétaire + enseignants
- AnneeSeeder       → 2024-2025 + 3 trimestres
- EleveSeeder       → 15-20 élèves/classe, noms africains
- AffectationSeeder → lie enseignants aux classes/matières

Commande finale : php artisan migrate:fresh --seed