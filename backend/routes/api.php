<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\Auth\InscriptionEcoleController;
use App\Http\Controllers\Api\Auth\ConnexionController;
use App\Http\Controllers\Api\UtilisateurController;
use App\Http\Controllers\Api\ClasseController;
use App\Http\Controllers\Api\MatiereController;
use App\Http\Controllers\Api\ClasseMatiereController;
use App\Http\Controllers\Api\ChangerMotDePasseController;
use App\Http\Controllers\Api\AffectationController;
use App\Http\Controllers\Api\AnneeAcademiqueController;
use App\Http\Controllers\Api\PeriodeAcademiqueController;
use App\Http\Controllers\Api\EleveController;
use App\Http\Controllers\Api\NoteController;
use App\Http\Controllers\Api\PaiementController;
use App\Http\Controllers\Api\ProfilController;
use App\Http\Controllers\Api\StatistiqueController;
use App\Http\Controllers\Api\BulletinController;
use App\Http\Controllers\Api\AbsenceController;
use App\Http\Controllers\Api\NotificationAttenteController;
use App\Http\Controllers\Api\AppreciationController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\EvaluationController;
use App\Http\Controllers\Api\FraisScolaireController;
use App\Http\Controllers\Api\EmploiDuTempsController;
use App\Http\Controllers\Api\CahierTexteController;
use App\Http\Controllers\Api\DisciplineController;



// ── Test ─────────────────────────────────────────────────
Route::get('/ping', fn() => response()->json([
    'statut'  => 'ok',
    'message' => 'API SSM opérationnelle'
]));

// ── Onboarding ───────────────────────────────────────────
Route::post('/inscrire-ecole', [InscriptionEcoleController::class, 'inscrire']);

// ── Authentification ─────────────────────────────────────
Route::post('/connexion', [ConnexionController::class, 'connecter']);

// ── Routes protégées ─────────────────────────────────────
Route::middleware('auth:sanctum')->group(function () {

    // Auth
    Route::post('/deconnexion',          [ConnexionController::class, 'deconnecter']);
    Route::get('/moi',                   [ConnexionController::class, 'moi']);
    Route::post('/changer-mot-de-passe', [ChangerMotDePasseController::class, 'changer']);

    // Utilisateurs
    Route::get('/utilisateurs/tableau-de-bord',    [UtilisateurController::class, 'tableau_de_bord']);
    Route::get('/utilisateurs/exporter-pdf',       [UtilisateurController::class, 'exporterPdf']);
    Route::get('/utilisateurs/exporter-excel',     [UtilisateurController::class, 'exporterExcel']);
    Route::post('/utilisateurs/importer',          [UtilisateurController::class, 'importerExcel']);
    Route::get('/utilisateurs',                    [UtilisateurController::class, 'index']);
    Route::get('/utilisateurs/{id}',                [UtilisateurController::class, 'show']);
    Route::post('/utilisateurs',                   [UtilisateurController::class, 'creer']);
    Route::patch('/utilisateurs/{id}',             [UtilisateurController::class, 'modifier']);
    Route::patch('/utilisateurs/{id}/desactiver',  [UtilisateurController::class, 'desactiver']);
    Route::patch('/utilisateurs/{id}/reactiver',   [UtilisateurController::class, 'reactiver']);
    Route::patch('/utilisateurs/{id}/reinitialiser-mdp', [UtilisateurController::class, 'reinitialiserMotDePasse']);
    Route::patch('/utilisateurs/{id}/role',        [UtilisateurController::class, 'modifierRole']);
    Route::patch('/utilisateurs/{id}/modules',     [UtilisateurController::class, 'modifierModules']);

    // Classes
    Route::get('/classes',                     [ClasseController::class, 'index']);
    Route::post('/classes',                    [ClasseController::class, 'store']);
    Route::post('/classes/transferer-eleve',   [ClasseController::class, 'transfererEleve']);
    Route::get('/classes/{id}',                [ClasseController::class, 'show']);
    Route::put('/classes/{id}',                [ClasseController::class, 'update']);
    Route::patch('/classes/{id}/archiver',     [ClasseController::class, 'archiverClasse']);
    Route::patch('/classes/{id}/activer',      [ClasseController::class, 'activerClasse']);
    Route::get('/classes/{id}/exporter-pdf',   [ClasseController::class, 'exporterListePdf']);
    Route::get('/classes/{id}/exporter-excel', [ClasseController::class, 'exporterListeExcel']);

    // Matières
    Route::get('/matieres/statistiques', [MatiereController::class, 'statistiques']);
    Route::get('/matieres',              [MatiereController::class, 'index']);
    Route::post('/matieres',             [MatiereController::class, 'store']);
    Route::put('/matieres/{id}',         [MatiereController::class, 'update']);
    Route::delete('/matieres/{id}',      [MatiereController::class, 'destroy']);

    // Matières par classe (coefficients)
    Route::get('/classe-matieres',         [ClasseMatiereController::class, 'index']);
    Route::post('/classe-matieres',        [ClasseMatiereController::class, 'enregistrer']);
    Route::delete('/classe-matieres/{id}', [ClasseMatiereController::class, 'supprimer']);

    // Évaluations (devoirs & compositions)
    Route::get('/evaluations',                [EvaluationController::class, 'index']);
    Route::post('/evaluations',               [EvaluationController::class, 'creer']);
    Route::post('/evaluations/{id}/notes',    [EvaluationController::class, 'saisirNotes']);
    Route::get('/evaluations/moyenne',        [EvaluationController::class, 'calculerMoyenne']);
    Route::get('/evaluations/moyennes-classe', [EvaluationController::class, 'moyennesClasse']);

    // Frais scolaires
    Route::get('/frais-scolaires',                     [FraisScolaireController::class, 'index']);
    Route::post('/frais-scolaires',                    [FraisScolaireController::class, 'enregistrer']);
    Route::get('/frais-scolaires/situation/{eleveId}',  [FraisScolaireController::class, 'situationEleve']);
    Route::get('/frais-scolaires/situation-classe',     [FraisScolaireController::class, 'situationClasse']);
    Route::get('/frais-scolaires/rapport',              [FraisScolaireController::class, 'rapportFinancier']);
    Route::get('/frais-scolaires/rapport-pdf',          [FraisScolaireController::class, 'genererRapportPdf']);

    // Emploi du temps
    Route::get('/emploi-du-temps/classe',              [EmploiDuTempsController::class, 'parClasse']);
    Route::get('/emploi-du-temps/pdf-classe',           [EmploiDuTempsController::class, 'genererPdfClasse']);
    Route::get('/emploi-du-temps/enseignant',           [EmploiDuTempsController::class, 'parEnseignant']);
    Route::get('/emploi-du-temps/pdf-enseignant',       [EmploiDuTempsController::class, 'genererPdfEnseignant']);
    Route::post('/emploi-du-temps',                     [EmploiDuTempsController::class, 'enregistrer']);
    Route::delete('/emploi-du-temps/{id}',              [EmploiDuTempsController::class, 'supprimer']);
    Route::post('/emploi-du-temps/verifier-conflits',   [EmploiDuTempsController::class, 'verifierConflits']);

    // Affectations
    Route::get('/affectations',                [AffectationController::class, 'parClasse']);
    Route::get('/affectations/{enseignantId}', [AffectationController::class, 'index']);
    Route::post('/affectations',               [AffectationController::class, 'ajouter']);
    Route::delete('/affectations/{id}',        [AffectationController::class, 'supprimer']);

    // Années académiques
    Route::get('/annees',    [AnneeAcademiqueController::class, 'index']);
    Route::post('/annees',   [AnneeAcademiqueController::class, 'creer']);

    // Périodes
    Route::get('/periodes/{anneeId}',         [PeriodeAcademiqueController::class, 'index']);
    Route::post('/periodes',                  [PeriodeAcademiqueController::class, 'creer']);
    Route::patch('/periodes/{id}/statut',     [PeriodeAcademiqueController::class, 'changerStatut']);

    // Élèves
    Route::get('/eleves',                    [EleveController::class, 'index']);
    Route::get('/eleves/classe/{classeId}',  [EleveController::class, 'parClasse']);
    Route::post('/eleves',                   [EleveController::class, 'creer']);
    Route::get('/eleves/{id}',               [EleveController::class, 'show']);

    // Notes
    Route::get('/notes',              [NoteController::class, 'index']);
    Route::post('/notes',             [NoteController::class, 'sauvegarder']);
    Route::post('/notes/soumettre',   [NoteController::class, 'soumettre']);
    Route::post('/notes/valider',     [NoteController::class, 'valider']);
    Route::post('/notes/rejeter',     [NoteController::class, 'rejeter']);

    

// Paiements
Route::get('/paiements',                   [PaiementController::class, 'index']);
Route::get('/paiements/eleve/{eleveId}',   [PaiementController::class, 'parEleve']);
Route::post('/paiements',                  [PaiementController::class, 'enregistrer']);
Route::post('/paiements/liste-renvoi',     [PaiementController::class, 'listeRenvoi']);
Route::get('/paiements/statistiques',      [PaiementController::class, 'statistiques']);



// Dans le groupe auth:sanctum
Route::get('/profil',                   [ProfilController::class, 'index']);
Route::patch('/profil',                 [ProfilController::class, 'modifier']);
Route::post('/profil/mot-de-passe',     [ProfilController::class, 'changerMotDePasse']);

// Dans le groupe auth:sanctum
Route::get('/statistiques', [StatistiqueController::class, 'index']);



// Dans le groupe auth:sanctum
Route::post('/bulletins/eleve',  [BulletinController::class, 'generer']);
Route::post('/bulletins/classe', [BulletinController::class, 'parClasse']);



// Dans le groupe auth:sanctum
Route::get('/absences',                    [AbsenceController::class, 'index']);
Route::post('/absences',                   [AbsenceController::class, 'enregistrer']);
Route::patch('/absences/{id}/notifie',     [AbsenceController::class, 'marquerNotifie']);
Route::patch('/absences/{id}/justifier',   [AbsenceController::class, 'justifier']);
Route::get('/absences/eleve/{eleveId}',    [AbsenceController::class, 'parEleve']);
Route::get('/absences/statistiques',       [AbsenceController::class, 'statistiques']);
Route::post('/bulletins/eleve/pdf', [BulletinController::class, 'genererPdf']);
Route::get('/paiements/{id}/recu', [PaiementController::class, 'genererRecuPdf']);
Route::post('/eleves/{id}/photo', [EleveController::class, 'uploaderPhoto']);


// Dans le groupe auth:sanctum
Route::get('/notifications-attente',                  [NotificationAttenteController::class, 'index']);
Route::patch('/notifications-attente/{id}/envoyee',   [NotificationAttenteController::class, 'marquerEnvoyee']);
Route::delete('/notifications-attente/{id}',          [NotificationAttenteController::class, 'supprimer']);
Route::post('/bulletins/notifier', [BulletinController::class, 'notifierBulletin']);



// Dans le groupe auth:sanctum
Route::get('/appreciations',                    [AppreciationController::class, 'index']);
Route::post('/appreciations',                   [AppreciationController::class, 'enregistrer']);
Route::get('/appreciations/suggerer',           [AppreciationController::class, 'suggererObservation']);


// Dans le groupe auth:sanctum
Route::get('/dashboard', [DashboardController::class, 'index']);

// Cahier de texte
Route::get('/cahier-texte',              [CahierTexteController::class, 'index']);
Route::post('/cahier-texte',             [CahierTexteController::class, 'store']);
Route::put('/cahier-texte/{id}',         [CahierTexteController::class, 'update']);
Route::get('/cahier-texte/classe/{classeId}', [CahierTexteController::class, 'historiqueClasse']);

// Discipline
Route::get('/sanctions',                  [DisciplineController::class, 'index']);
Route::post('/sanctions',                 [DisciplineController::class, 'store']);
Route::get('/sanctions/eleve/{eleveId}',  [DisciplineController::class, 'historiqueEleve']);
Route::get('/sanctions/statistiques',     [DisciplineController::class, 'statistiques']);
Route::patch('/sanctions/{id}/notifier',  [DisciplineController::class, 'notifier']);

});