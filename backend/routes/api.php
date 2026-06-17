<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\Auth\InscriptionEcoleController;
use App\Http\Controllers\Api\Auth\ConnexionController;
use App\Http\Controllers\Api\UtilisateurController;
use App\Http\Controllers\Api\ClasseController;
use App\Http\Controllers\Api\MatiereController;
use App\Http\Controllers\Api\ChangerMotDePasseController;
use App\Http\Controllers\Api\AffectationController;

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

    // ✅ Affectations — DANS le middleware
    Route::get('/affectations/{enseignantId}', [AffectationController::class, 'index']);
    Route::post('/affectations',               [AffectationController::class, 'ajouter']);
    Route::delete('/affectations/{id}',        [AffectationController::class, 'supprimer']);
});