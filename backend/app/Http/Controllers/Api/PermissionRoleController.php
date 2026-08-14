<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PermissionRole;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Matrice de droits par rôle × module (permissions_roles). Distincte de
 * permissions_modules (module Utilisateurs existant), qui autorise/retire
 * un module à un utilisateur PRÉCIS (exception ponctuelle) : ici on définit
 * le droit par défaut de chaque RÔLE, consulté par VerifierPermissionMiddleware
 * (voir ce fichier) — un complément progressif aux vérifications de rôle en
 * dur déjà présentes dans les contrôleurs existants (ex.
 * ValidationNoteController::autoriserGestionnaire()).
 */
class PermissionRoleController extends Controller
{
    // GET /parametres/permissions
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $existantes = PermissionRole::where('ecole_id', $ecoleId)
            ->get()
            ->keyBy(fn ($p) => $p->role . '|' . $p->module);

        $matrice = [];
        foreach (PermissionRole::ROLES as $role) {
            foreach (PermissionRole::MODULES as $module => $libelleModule) {
                $existante = $existantes->get("{$role}|{$module}");

                $matrice[] = [
                    'role'           => $role,
                    'module'         => $module,
                    'module_libelle' => $libelleModule,
                    'peut_consulter' => $existante->peut_consulter ?? PermissionRole::droitsParDefaut($role, $module)['peut_consulter'],
                    'peut_creer'     => $existante->peut_creer ?? PermissionRole::droitsParDefaut($role, $module)['peut_creer'],
                    'peut_modifier'  => $existante->peut_modifier ?? PermissionRole::droitsParDefaut($role, $module)['peut_modifier'],
                    'peut_supprimer' => $existante->peut_supprimer ?? PermissionRole::droitsParDefaut($role, $module)['peut_supprimer'],
                    'peut_valider'   => $existante->peut_valider ?? PermissionRole::droitsParDefaut($role, $module)['peut_valider'],
                ];
            }
        }

        return response()->json([
            'roles'    => PermissionRole::ROLES,
            'modules'  => PermissionRole::MODULES,
            'matrice'  => $matrice,
        ]);
    }

    // PUT /parametres/permissions (directeur uniquement)
    public function update(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut modifier la matrice de permissions.',
            ], 403);
        }

        $data = $request->validate([
            'role'           => 'required|in:' . implode(',', PermissionRole::ROLES),
            'module'         => 'required|in:' . implode(',', array_keys(PermissionRole::MODULES)),
            'peut_consulter' => 'required|boolean',
            'peut_creer'     => 'required|boolean',
            'peut_modifier'  => 'required|boolean',
            'peut_supprimer' => 'required|boolean',
            'peut_valider'   => 'required|boolean',
        ]);

        // Sécurité anti-blocage : le directeur garde toujours un accès
        // complet, y compris sur lui-même — sinon il pourrait se retirer
        // par erreur l'accès qui lui permet justement de corriger la
        // matrice, sans recours possible.
        if ($data['role'] === 'directeur') {
            return response()->json([
                'message' => 'Le rôle directeur conserve toujours un accès complet ; ses permissions ne sont pas modifiables.',
            ], 422);
        }

        $permission = PermissionRole::updateOrCreate(
            ['ecole_id' => $request->user()->ecole_id, 'role' => $data['role'], 'module' => $data['module']],
            [
                'peut_consulter' => $data['peut_consulter'],
                'peut_creer'     => $data['peut_creer'],
                'peut_modifier'  => $data['peut_modifier'],
                'peut_supprimer' => $data['peut_supprimer'],
                'peut_valider'   => $data['peut_valider'],
            ]
        );

        return response()->json([
            'message'    => 'Permission mise à jour avec succès',
            'permission' => $permission,
        ]);
    }

    // POST /parametres/permissions/reinitialiser (directeur uniquement)
    public function reinitialiserDefauts(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut réinitialiser les permissions.',
            ], 403);
        }

        $ecoleId = $request->user()->ecole_id;

        DB::transaction(function () use ($ecoleId) {
            PermissionRole::where('ecole_id', $ecoleId)->delete();
            // Boucle plutôt qu'un insert() en masse : passe par Eloquent
            // (created_at/updated_at, casts) pour rester cohérent avec le
            // reste du modèle — 75 lignes (5 rôles × 15 modules), sans enjeu
            // de performance.
            foreach (PermissionRole::lignesDefaut($ecoleId) as $ligne) {
                PermissionRole::create($ligne);
            }
        });

        return response()->json([
            'message' => 'Permissions réinitialisées aux valeurs par défaut avec succès',
        ]);
    }
}
