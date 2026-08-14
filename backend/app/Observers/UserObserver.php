<?php

namespace App\Observers;

use App\Models\ConnexionUtilisateur;
use App\Models\User;

/**
 * Enregistre automatiquement une ligne dans connexions_utilisateurs à
 * chaque connexion réussie. Il n'y a pas d'événement Laravel "Login" ici :
 * l'authentification est manuelle (voir Auth\ConnexionController::connecter(),
 * qui compare le mot de passe à la main et crée le token Sanctum), donc pas
 * de listener sur Illuminate\Auth\Events\Login. En revanche
 * ConnexionController::connecter() est le SEUL endroit du projet qui
 * modifie users.derniere_connexion — cet observer s'appuie sur ce signal
 * plutôt que de dupliquer la logique de connexion.
 */
class UserObserver
{
    public function updated(User $user): void
    {
        if (!$user->wasChanged('derniere_connexion')) {
            return;
        }

        ConnexionUtilisateur::create([
            'user_id'        => $user->id,
            'ecole_id'       => $user->ecole_id,
            'date_connexion' => $user->derniere_connexion ?? now(),
            'ip'             => request()->ip(),
            'appareil'       => substr((string) request()->userAgent(), 0, 191),
        ]);
    }
}
