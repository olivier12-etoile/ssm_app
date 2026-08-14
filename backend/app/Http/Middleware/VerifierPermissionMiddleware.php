<?php

namespace App\Http\Middleware;

use App\Models\PermissionRole;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Bloque une route si le rôle de l'utilisateur connecté n'a pas le droit
 * demandé (permissions_roles) sur le module concerné.
 *
 * IMPORTANT — statut du projet : ce middleware est un COMPLÉMENT au système
 * de permissions, pas un remplacement des contrôles déjà en place. La
 * grande majorité des contrôleurs existants (NoteController,
 * ValidationNoteController, PaiementController, CorrectionPaiementController,
 * ClasseController, ...) vérifient encore le rôle en dur
 * (`$request->user()->role !== 'directeur'`, `abort_unless(in_array(...))`).
 * Ce middleware n'est câblé sur AUCUNE de ces routes existantes : l'adopter
 * est une migration progressive, module par module, à faire séparément
 * pour éviter de changer le comportement de routes déjà en production sans
 * revue dédiée.
 *
 * Usage prévu, une fois adopté sur une route :
 *   Route::get('/eleves', [EleveController::class, 'index'])
 *       ->middleware('permission:eleves,consulter');
 *
 * Alias 'permission' enregistré dans bootstrap/app.php.
 */
class VerifierPermissionMiddleware
{
    private const DROIT_VERS_COLONNE = [
        'consulter' => 'peut_consulter',
        'creer'     => 'peut_creer',
        'modifier'  => 'peut_modifier',
        'supprimer' => 'peut_supprimer',
        'valider'   => 'peut_valider',
    ];

    /**
     * @param string $module Clé technique du module (voir PermissionRole::MODULES)
     * @param string $droit  consulter|creer|modifier|supprimer|valider
     */
    public function handle(Request $request, Closure $next, string $module, string $droit = 'consulter'): Response
    {
        $utilisateur = $request->user();

        if (!$utilisateur) {
            return response()->json(['message' => 'Non authentifié.'], 401);
        }

        // Le directeur a toujours accès complet (cohérent avec
        // PermissionRoleController::update(), qui rend ses lignes immuables).
        if ($utilisateur->role === 'directeur') {
            return $next($request);
        }

        $colonne = self::DROIT_VERS_COLONNE[$droit] ?? null;

        if (!$colonne) {
            return response()->json(['message' => "Droit de permission inconnu : {$droit}."], 500);
        }

        $autorise = PermissionRole::droitsParDefaut($utilisateur->role, $module)[$colonne] ?? false;

        $permission = PermissionRole::where('ecole_id', $utilisateur->ecole_id)
            ->where('role', $utilisateur->role)
            ->where('module', $module)
            ->first();

        if ($permission) {
            $autorise = (bool) $permission->{$colonne};
        }

        if (!$autorise) {
            return response()->json([
                'message' => "Votre rôle ({$utilisateur->role}) n'a pas le droit \"{$droit}\" sur le module \"{$module}\".",
            ], 403);
        }

        return $next($request);
    }
}
