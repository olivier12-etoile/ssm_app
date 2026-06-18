<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\Auth\InscriptionEcoleController;
use App\Http\Controllers\Api\Auth\ConnexionController;
use App\Http\Controllers\Api\UtilisateurController;
use App\Http\Controllers\Api\ClasseController;
use App\Http\Controllers\Api\MatiereController;
use App\Http\Controllers\Api\ChangerMotDePasseController;
use App\Http\Controllers\Api\AffectationController;
use App\Http\Controllers\Api\AnneeAcademiqueController;
use App\Http\Controllers\Api\PeriodeAcademiqueController;
use App\Http\Controllers\Api\EleveController;
use App\Http\Controllers\Api\NoteController;
use App\Http\Controllers\Api\PaiementController;

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
    Route::get('/utilisateurs',                [UtilisateurController::class, 'index']);
    Route::post('/utilisateurs',               [UtilisateurController::class, 'creer']);
    Route::patch('/utilisateurs/{id}/role',    [UtilisateurController::class, 'modifierRole']);
    Route::patch('/utilisateurs/{id}/modules', [UtilisateurController::class, 'modifierModules']);

    // Classes
    Route::get('/classes',         [ClasseController::class, 'index']);
    Route::post('/classes',        [ClasseController::class, 'creer']);
    Route::patch('/classes/{id}',  [ClasseController::class, 'modifier']);
    Route::delete('/classes/{id}', [ClasseController::class, 'supprimer']);

    // Matières
    Route::get('/matieres',         [MatiereController::class, 'index']);
    Route::post('/matieres',        [MatiereController::class, 'creer']);
    Route::patch('/matieres/{id}',  [MatiereController::class, 'modifier']);
    Route::delete('/matieres/{id}', [MatiereController::class, 'supprimer']);

    // Affectations
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
});