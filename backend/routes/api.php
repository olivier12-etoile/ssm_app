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
use App\Http\Controllers\Api\DashboardStatistiqueController;
use App\Http\Controllers\Api\StatistiqueInscriptionController;
use App\Http\Controllers\Api\StatistiquePaiementController;
use App\Http\Controllers\Api\StatistiquePedagogiqueController;
use App\Http\Controllers\Api\CentreDecisionController;
use App\Http\Controllers\Api\RapportStatistiqueController;
use App\Http\Controllers\Api\BulletinController;
use App\Http\Controllers\Api\AbsenceController;
use App\Http\Controllers\Api\NotificationAttenteController;
use App\Http\Controllers\Api\AppreciationController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\SaisieNoteController;
use App\Http\Controllers\Api\SoumissionController;
use App\Http\Controllers\Api\ValidationNoteController;
use App\Http\Controllers\Api\DeverrouillageController;
use App\Http\Controllers\Api\AnalysePerformanceController;
use App\Http\Controllers\Api\ExportNoteController;
use App\Http\Controllers\Api\FraisScolaireController;
use App\Http\Controllers\Api\DashboardFraisController;
use App\Http\Controllers\Api\SituationFinanciereController;
use App\Http\Controllers\Api\CaisseController;
use App\Http\Controllers\Api\CorrectionPaiementController;
use App\Http\Controllers\Api\SituationFinanciereClasseController;
use App\Http\Controllers\Api\RapportPaiementController;
use App\Http\Controllers\Api\RemiseController;
use App\Http\Controllers\Api\ExonerationController;
use App\Http\Controllers\Api\EmploiDuTempsController;
use App\Http\Controllers\Api\CreneauHoraireController;
use App\Http\Controllers\Api\JourTravailleController;
use App\Http\Controllers\Api\SeanceController;
use App\Http\Controllers\Api\ConsultationEmploiDuTempsController;
use App\Http\Controllers\Api\DuplicationEmploiDuTempsController;
use App\Http\Controllers\Api\RemplacementController;
use App\Http\Controllers\Api\DisponibiliteEnseignantController;
use App\Http\Controllers\Api\DashboardEmploiDuTempsController;
use App\Http\Controllers\Api\StatistiqueEmploiDuTempsController;
use App\Http\Controllers\Api\CalendrierController;
use App\Http\Controllers\Api\ExportEmploiDuTempsController;
use App\Http\Controllers\Api\CahierTexteController;
use App\Http\Controllers\Api\DisciplineController;
use App\Http\Controllers\Api\ModeleMessageController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\ParametreNotificationController;
use App\Http\Controllers\Api\StatistiqueNotificationController;



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

    // Frais scolaires
    Route::prefix('frais-scolaires')->group(function () {
        Route::get('/',        [FraisScolaireController::class, 'index']);
        Route::post('/',       [FraisScolaireController::class, 'store']);
        Route::get('/{id}',    [FraisScolaireController::class, 'show']);
        Route::put('/{id}',    [FraisScolaireController::class, 'update']);
        Route::delete('/{id}', [FraisScolaireController::class, 'destroy']);
    });

    // Frais scolaires — tableau de bord et rapports
    Route::prefix('frais-scolaires/dashboard')->group(function () {
        Route::get('/resume',                 [DashboardFraisController::class, 'resume']);
        Route::get('/debiteurs',              [DashboardFraisController::class, 'debiteurs']);
        Route::get('/a-jour',                 [DashboardFraisController::class, 'elevesAJour']);
        Route::get('/statistiques',           [DashboardFraisController::class, 'statistiques']);
        Route::get('/rapport',                [DashboardFraisController::class, 'rapport']);
        Route::get('/journal',                [DashboardFraisController::class, 'journalOperations']);
        Route::get('/debiteurs/export-excel', [DashboardFraisController::class, 'exportDebiteursExcel']);
        Route::get('/debiteurs/export-pdf',   [DashboardFraisController::class, 'exportDebiteursPdf']);
    });

    // Paiements
    Route::get('/paiements',                [PaiementController::class, 'index']);
    Route::post('/paiements',               [PaiementController::class, 'store']);
    Route::post('/paiements/{id}/annuler',  [PaiementController::class, 'annuler']);
    Route::get('/paiements/{id}/recu',      [PaiementController::class, 'recu']);

    // Situation financière
    Route::get('/eleves/{id}/situation-financiere', [SituationFinanciereController::class, 'show']);

    // Paiements — caisses, corrections, statut financier
    Route::prefix('paiements')->group(function () {
        Route::get('/caisses',                    [CaisseController::class, 'index']);
        Route::post('/caisses',                   [CaisseController::class, 'store']);
        Route::post('/caisses/ouvrir',             [CaisseController::class, 'ouvrir']);
        Route::post('/caisses/fermer',             [CaisseController::class, 'fermer']);
        Route::get('/caisses/{id}/session-active', [CaisseController::class, 'sessionActive']);
        Route::get('/caisses/{id}/historique',     [CaisseController::class, 'historique']);

        Route::post('/corrections',                     [CorrectionPaiementController::class, 'store']);
        Route::get('/corrections/{paiementId}/historique', [CorrectionPaiementController::class, 'historique']);

        Route::get('/eleves/{id}/statut-financier', [SituationFinanciereController::class, 'statutFinancier']);

        // Situation financière par classe — les routes littérales
        // ("export-pdf", "export-excel") doivent être déclarées avant
        // '/situation-classe/{classeId}' pour ne pas être capturées par le
        // paramètre dynamique.
        Route::get('/situation-classe/export-pdf',              [SituationFinanciereClasseController::class, 'exportToutesClassesPdf']);
        Route::get('/situation-classe/export-excel',            [SituationFinanciereClasseController::class, 'exportToutesClassesExcel']);
        Route::get('/situation-classe',                         [SituationFinanciereClasseController::class, 'toutesLesClasses']);
        Route::get('/situation-classe/{classeId}/impayes',      [SituationFinanciereClasseController::class, 'impayes']);
        Route::get('/situation-classe/{classeId}/export-pdf',   [SituationFinanciereClasseController::class, 'exportClassePdf']);
        Route::get('/situation-classe/{classeId}/export-excel', [SituationFinanciereClasseController::class, 'exportClasseExcel']);
        Route::get('/situation-classe/{classeId}',               [SituationFinanciereClasseController::class, 'parClasse']);

        // Rapports de paiements
        Route::get('/rapports/journalier',    [RapportPaiementController::class, 'journalier']);
        Route::get('/rapports/hebdomadaire',  [RapportPaiementController::class, 'hebdomadaire']);
        Route::get('/rapports/mensuel',       [RapportPaiementController::class, 'mensuel']);
        Route::get('/rapports/annuel',        [RapportPaiementController::class, 'annuel']);
        Route::get('/rapports/personnalise',  [RapportPaiementController::class, 'personnalise']);
        Route::get('/rapports/export',        [RapportPaiementController::class, 'export']);
    });

    // Remises
    Route::get('/remises',        [RemiseController::class, 'index']);
    Route::post('/remises',       [RemiseController::class, 'store']);
    Route::put('/remises/{id}',   [RemiseController::class, 'update']);
    Route::delete('/remises/{id}', [RemiseController::class, 'destroy']);

    // Exonérations
    Route::get('/exonerations',        [ExonerationController::class, 'index']);
    Route::post('/exonerations',       [ExonerationController::class, 'store']);
    Route::put('/exonerations/{id}',   [ExonerationController::class, 'update']);
    Route::delete('/exonerations/{id}', [ExonerationController::class, 'destroy']);

    // Emploi du temps
    Route::prefix('emploi-du-temps')->group(function () {
        Route::get('/creneaux-horaires',        [CreneauHoraireController::class, 'index']);
        Route::post('/creneaux-horaires',       [CreneauHoraireController::class, 'store']);
        Route::put('/creneaux-horaires/{id}',   [CreneauHoraireController::class, 'update']);
        Route::delete('/creneaux-horaires/{id}', [CreneauHoraireController::class, 'destroy']);

        Route::get('/jours-travailles',        [JourTravailleController::class, 'index']);
        Route::post('/jours-travailles',       [JourTravailleController::class, 'store']);
        Route::put('/jours-travailles/{id}',   [JourTravailleController::class, 'update']);
        Route::delete('/jours-travailles/{id}', [JourTravailleController::class, 'destroy']);

        Route::get('/emplois-du-temps',              [EmploiDuTempsController::class, 'index']);
        Route::post('/emplois-du-temps',             [EmploiDuTempsController::class, 'store']);
        Route::get('/emplois-du-temps/{id}',         [EmploiDuTempsController::class, 'show']);
        Route::post('/emplois-du-temps/{id}/valider', [EmploiDuTempsController::class, 'valider']);
        Route::delete('/emplois-du-temps/{id}',      [EmploiDuTempsController::class, 'destroy']);

        Route::post('/seances',        [SeanceController::class, 'store']);
        Route::post('/seances/bulk',   [SeanceController::class, 'storeBulk']);
        Route::put('/seances/{id}',    [SeanceController::class, 'update']);
        Route::delete('/seances/{id}', [SeanceController::class, 'destroy']);

        Route::get('/consultation/classe/{classeId}', [ConsultationEmploiDuTempsController::class, 'parClasse']);
        Route::get('/consultation/mon-emploi-du-temps', [ConsultationEmploiDuTempsController::class, 'monEmploiDuTemps']);
        Route::get('/consultation/toutes-classes',    [ConsultationEmploiDuTempsController::class, 'toutesLesClasses']);

        Route::post('/duplication', [DuplicationEmploiDuTempsController::class, 'dupliquer']);

        Route::get('/remplacements',        [RemplacementController::class, 'index']);
        Route::post('/remplacements',       [RemplacementController::class, 'store']);
        Route::delete('/remplacements/{id}', [RemplacementController::class, 'destroy']);

        // La route "creneau" doit être déclarée avant "{enseignantId}" pour ne pas être capturée comme un id.
        Route::get('/disponibilite/creneau',        [DisponibiliteEnseignantController::class, 'tousLesEnseignants']);
        Route::get('/disponibilite/{enseignantId}', [DisponibiliteEnseignantController::class, 'index']);

        Route::get('/dashboard/resume', [DashboardEmploiDuTempsController::class, 'resume']);

        Route::get('/statistiques/heures-enseignant', [StatistiqueEmploiDuTempsController::class, 'heuresParEnseignant']);
        Route::get('/statistiques/heures-matiere',    [StatistiqueEmploiDuTempsController::class, 'heuresParMatiere']);
        Route::get('/statistiques/heures-classe',     [StatistiqueEmploiDuTempsController::class, 'heuresParClasse']);
        Route::get('/statistiques/taux-completion',   [StatistiqueEmploiDuTempsController::class, 'tauxCompletionGlobal']);

        // "verifier-date" doit être déclarée avant les routes {id} pour ne pas être capturée comme un id.
        Route::get('/calendrier/verifier-date', [CalendrierController::class, 'verifierDateLibre']);
        Route::get('/calendrier',        [CalendrierController::class, 'index']);
        Route::post('/calendrier',       [CalendrierController::class, 'store']);
        Route::put('/calendrier/{id}',   [CalendrierController::class, 'update']);
        Route::delete('/calendrier/{id}', [CalendrierController::class, 'destroy']);

        Route::get('/export/classe/{classeId}/pdf',        [ExportEmploiDuTempsController::class, 'exportClassePdf']);
        Route::get('/export/classe/{classeId}/excel',      [ExportEmploiDuTempsController::class, 'exportClasseExcel']);
        Route::get('/export/enseignant/{enseignantId}/pdf', [ExportEmploiDuTempsController::class, 'exportEnseignantPdf']);
    });

    // Affectations
    Route::get('/affectations',                [AffectationController::class, 'parClasse']);
    Route::get('/affectations/{enseignantId}', [AffectationController::class, 'index']);
    Route::post('/affectations',               [AffectationController::class, 'ajouter']);
    Route::delete('/affectations/{id}',        [AffectationController::class, 'supprimer']);

    // Années académiques
    Route::get('/annees/tableau-de-bord',     [AnneeAcademiqueController::class, 'tableauDeBord']);
    Route::get('/annees/rangs',               [AnneeAcademiqueController::class, 'rangsClasse']);
    Route::get('/annees/rangs/pdf',           [AnneeAcademiqueController::class, 'exporterRangsPdf']);
    Route::get('/annees/eleves-non-en-regle',        [AnneeAcademiqueController::class, 'elevesNonEnRegle']);
    Route::get('/annees/eleves-non-en-regle/pdf',    [AnneeAcademiqueController::class, 'exporterElevesNonEnReglePdf']);
    Route::get('/annees/eleves-non-en-regle/excel',  [AnneeAcademiqueController::class, 'exporterElevesNonEnRegleExcel']);
    Route::get('/annees/rapport/{periodeId}', [AnneeAcademiqueController::class, 'rapportPeriode']);
    Route::get('/annees/journal',             [AnneeAcademiqueController::class, 'journalActions']);
    Route::get('/annees',                     [AnneeAcademiqueController::class, 'index']);
    Route::get('/annees/active',              [AnneeAcademiqueController::class, 'anneeActive']);
    Route::get('/annees/historique',          [AnneeAcademiqueController::class, 'historique']);
    Route::post('/annees',                    [AnneeAcademiqueController::class, 'store']);
    Route::patch('/annees/{id}/activer',      [AnneeAcademiqueController::class, 'activer']);
    Route::patch('/annees/{id}/cloturer',     [AnneeAcademiqueController::class, 'cloturer']);
    Route::patch('/annees/{id}/archiver',     [AnneeAcademiqueController::class, 'archiver']);
    Route::post('/annees/{id}/passer-eleves', [AnneeAcademiqueController::class, 'passerEleves']);
    Route::get('/annees/{id}/statistiques',   [AnneeAcademiqueController::class, 'statistiques']);
    Route::get('/annees/{id}/passage-apercu', [AnneeAcademiqueController::class, 'apercuPassage']);
    Route::get('/annees/{id}/details',        [AnneeAcademiqueController::class, 'details']);

    // Périodes
    Route::get('/periodes',                          [PeriodeAcademiqueController::class, 'index']);
    Route::post('/periodes',                         [PeriodeAcademiqueController::class, 'store']);
    Route::patch('/periodes/{id}/ouvrir',             [PeriodeAcademiqueController::class, 'ouvrir']);
    Route::patch('/periodes/{id}/en-validation',      [PeriodeAcademiqueController::class, 'mettreEnValidation']);
    Route::patch('/periodes/{id}/fermer',             [PeriodeAcademiqueController::class, 'fermer']);
    Route::patch('/periodes/{id}/reouvrir',           [PeriodeAcademiqueController::class, 'reouvrir']);
    Route::get('/periodes/{id}/etat-enseignants',     [PeriodeAcademiqueController::class, 'etatEnseignants']);
    Route::get('/periodes/{id}/verification',         [PeriodeAcademiqueController::class, 'verifierAvantCloture']);
    Route::post('/periodes/{id}/generer-bulletins',   [PeriodeAcademiqueController::class, 'genererBulletinsEnMasse']);
    Route::get('/periodes/alertes',                   [PeriodeAcademiqueController::class, 'alertes']);

    // Élèves
    Route::get('/eleves/tableau-de-bord',       [EleveController::class, 'tableauDeBord']);
    Route::get('/eleves/liste-intelligente',        [EleveController::class, 'listeIntelligente']);
    Route::get('/eleves/liste-intelligente/pdf',    [EleveController::class, 'exporterListeIntelligentePdf']);
    Route::get('/eleves/liste-intelligente/excel',  [EleveController::class, 'exporterListeIntelligenteExcel']);
    Route::get('/eleves/exporter-pdf',          [EleveController::class, 'exporterPdf']);
    Route::get('/eleves/exporter-excel',        [EleveController::class, 'exporterExcel']);
    Route::get('/eleves/classe/{classeId}',     [EleveController::class, 'elevesParClasse']);
    Route::get('/eleves',                       [EleveController::class, 'index']);
    Route::post('/eleves',                      [EleveController::class, 'store']);
    Route::get('/eleves/{id}',                  [EleveController::class, 'show']);
    Route::put('/eleves/{id}',                  [EleveController::class, 'update']);
    Route::patch('/eleves/{id}/statut',         [EleveController::class, 'changerStatut']);
    Route::post('/eleves/{id}/photo',           [EleveController::class, 'uploaderPhoto']);
    Route::post('/eleves/{id}/parents',         [EleveController::class, 'gererParents']);
    Route::post('/eleves/{id}/documents',       [EleveController::class, 'uploaderDocument']);
    Route::delete('/eleves/{eleveId}/documents/{docId}', [EleveController::class, 'supprimerDocument']);
    Route::get('/eleves/{id}/chronologie',      [EleveController::class, 'chronologie']);

    // Notes & Évaluations — saisie
    Route::prefix('notes')->group(function () {
        Route::post('/saisie/demarrer',       [SaisieNoteController::class, 'demarrer']);
        Route::get('/saisie/{id}/eleves',     [SaisieNoteController::class, 'eleves']);
        Route::get('/saisie/progression',     [SaisieNoteController::class, 'progression']);
        Route::post('/saisie/{id}/soumettre', [SoumissionController::class, 'soumettre']);

        Route::post('/bulk',        [NoteController::class, 'storeBulk']);
        Route::get('/statistiques', [NoteController::class, 'statistiques']);
        Route::post('/',            [NoteController::class, 'store']);
        Route::put('/{id}',         [NoteController::class, 'update']);
        Route::delete('/{id}',      [NoteController::class, 'destroy']);

        // Notes & Évaluations — validation
        Route::get('/validation/en-attente',           [ValidationNoteController::class, 'enAttente']);
        Route::get('/validation/historique',           [ValidationNoteController::class, 'historique']);
        Route::get('/validation/{saisieId}',           [ValidationNoteController::class, 'detail']);
        Route::post('/validation/{saisieId}/valider',  [ValidationNoteController::class, 'valider']);
        Route::post('/validation/{saisieId}/rejeter',  [ValidationNoteController::class, 'rejeter']);
        Route::post('/deverrouillage',                 [DeverrouillageController::class, 'deverrouiller']);

        // Notes & Évaluations — analyse de performance
        Route::get('/analyse/resume',                [AnalysePerformanceController::class, 'resume']);
        Route::get('/analyse/classes-incompletes',   [AnalysePerformanceController::class, 'classesIncompletes']);
        Route::get('/analyse/matieres-non-validees', [AnalysePerformanceController::class, 'matieresNonValidees']);
        Route::get('/analyse/enseignants-en-retard', [AnalysePerformanceController::class, 'enseignantsEnRetard']);
        Route::get('/analyse/eleves-faibles',        [AnalysePerformanceController::class, 'elevesFaibles']);
        Route::get('/analyse/eleves-excellents',     [AnalysePerformanceController::class, 'elevesExcellents']);
        Route::get('/analyse/classement-classes',    [AnalysePerformanceController::class, 'classementClasses']);

        // Notes & Évaluations — exports
        Route::get('/export/releve/{classeId}/{matiereId}/{periodeId}', [ExportNoteController::class, 'releveClasse']);
        Route::get('/export/analyse-performance',                       [ExportNoteController::class, 'analysePerformance']);
    });



// Dans le groupe auth:sanctum
Route::get('/profil',                   [ProfilController::class, 'index']);
Route::patch('/profil',                 [ProfilController::class, 'modifier']);
Route::post('/profil/mot-de-passe',     [ProfilController::class, 'changerMotDePasse']);

// Dans le groupe auth:sanctum
Route::get('/statistiques', [StatistiqueController::class, 'index']);

// Module Statistiques — tableau de bord général (agrège élèves, frais, notes)
Route::prefix('statistiques')->group(function () {
    Route::get('/dashboard/general',    [DashboardStatistiqueController::class, 'general']);
    Route::post('/dashboard/snapshot',  [DashboardStatistiqueController::class, 'snapshot']);
    Route::get('/dashboard/comparaison', [DashboardStatistiqueController::class, 'comparaison']);

    Route::get('/inscriptions/par-annee',  [StatistiqueInscriptionController::class, 'parAnnee']);
    Route::get('/inscriptions/par-niveau', [StatistiqueInscriptionController::class, 'parNiveau']);
    Route::get('/inscriptions/par-classe', [StatistiqueInscriptionController::class, 'parClasse']);
    Route::get('/inscriptions/par-sexe',   [StatistiqueInscriptionController::class, 'parSexe']);
    Route::get('/inscriptions/evolution',  [StatistiqueInscriptionController::class, 'evolution']);

    Route::get('/paiements/par-classe',         [StatistiquePaiementController::class, 'parClasse']);
    Route::get('/paiements/par-niveau',         [StatistiquePaiementController::class, 'parNiveau']);
    Route::get('/paiements/par-mois',           [StatistiquePaiementController::class, 'parMois']);
    Route::get('/paiements/eleves-non-en-regle', [StatistiquePaiementController::class, 'elevesNonEnRegle']);

    Route::get('/pedagogique/par-matiere',        [StatistiquePedagogiqueController::class, 'parMatiere']);
    Route::get('/pedagogique/par-enseignant',     [StatistiquePedagogiqueController::class, 'parEnseignant']);
    Route::get('/pedagogique/par-classe',         [StatistiquePedagogiqueController::class, 'parClasse']);
    Route::get('/pedagogique/meilleures-classes', [StatistiquePedagogiqueController::class, 'meilleuresClasses']);
    Route::get('/pedagogique/meilleurs-eleves',   [StatistiquePedagogiqueController::class, 'meilleursEleves']);
    Route::get('/pedagogique/eleves-en-difficulte', [StatistiquePedagogiqueController::class, 'elevesEnDifficulte']);

    Route::get('/centre-decision/alertes', [CentreDecisionController::class, 'alertes']);

    Route::get('/rapports/inscriptions',        [RapportStatistiqueController::class, 'inscriptions']);
    Route::get('/rapports/financier',           [RapportStatistiqueController::class, 'financier']);
    Route::get('/rapports/paiements',           [RapportStatistiqueController::class, 'paiements']);
    Route::get('/rapports/resultats',           [RapportStatistiqueController::class, 'resultats']);
    Route::get('/rapports/meilleurs-eleves',    [RapportStatistiqueController::class, 'meilleursEleves']);
    Route::get('/rapports/eleves-en-difficulte', [RapportStatistiqueController::class, 'elevesEnDifficulte']);
});



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
Route::delete('/cahier-texte/{id}',      [CahierTexteController::class, 'destroy']);
Route::get('/cahier-texte/classe/{classeId}', [CahierTexteController::class, 'historiqueClasse']);

// Discipline
Route::get('/sanctions',                  [DisciplineController::class, 'index']);
Route::post('/sanctions',                 [DisciplineController::class, 'store']);
Route::get('/sanctions/eleve/{eleveId}',  [DisciplineController::class, 'historiqueEleve']);
Route::get('/sanctions/statistiques',     [DisciplineController::class, 'statistiques']);
Route::patch('/sanctions/{id}/notifier',  [DisciplineController::class, 'notifier']);

// Notifications (notifications manuelles + modèles de messages)
Route::prefix('notifications')->group(function () {
    Route::get('/modeles',         [ModeleMessageController::class, 'index']);
    Route::post('/modeles',        [ModeleMessageController::class, 'store']);
    Route::put('/modeles/{id}',    [ModeleMessageController::class, 'update']);
    Route::delete('/modeles/{id}', [ModeleMessageController::class, 'destroy']);

    Route::post('/apercu-destinataires', [NotificationController::class, 'apercu']);
    Route::post('/apercu-message',       [NotificationController::class, 'apercuMessage']);

    Route::get('/parametres-declencheurs', [ParametreNotificationController::class, 'index']);
    Route::put('/parametres-declencheurs', [ParametreNotificationController::class, 'update']);

    Route::get('/statistiques',               [StatistiqueNotificationController::class, 'resume']);
    Route::get('/statistiques/par-canal',      [StatistiqueNotificationController::class, 'parCanal']);
    Route::get('/statistiques/par-categorie',  [StatistiqueNotificationController::class, 'parCategorie']);

    Route::get('/export-excel',  [NotificationController::class, 'exporterExcel']);

    Route::get('/',              [NotificationController::class, 'index']);
    Route::post('/',             [NotificationController::class, 'store']);
    Route::get('/{id}',          [NotificationController::class, 'show']);
    Route::post('/{id}/annuler', [NotificationController::class, 'annulerProgrammee']);
});

});