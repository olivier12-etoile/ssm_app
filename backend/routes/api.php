<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\Auth\InscriptionEcoleController;
use App\Http\Controllers\Api\Auth\ConnexionController;
use App\Http\Controllers\Api\UtilisateurController;

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
    Route::post('/deconnexion',     [ConnexionController::class, 'deconnecter']);
    Route::get('/moi',              [ConnexionController::class, 'moi']);

    // Gestion des utilisateurs
    Route::get('/utilisateurs',                        [UtilisateurController::class, 'index']);
    Route::post('/utilisateurs',                       [UtilisateurController::class, 'creer']);
    Route::patch('/utilisateurs/{id}/role',            [UtilisateurController::class, 'modifierRole']);
    Route::patch('/utilisateurs/{id}/modules',         [UtilisateurController::class, 'modifierModules']);
});