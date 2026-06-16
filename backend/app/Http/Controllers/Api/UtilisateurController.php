<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\PermissionModule;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class UtilisateurController extends Controller
{
    // Liste des utilisateurs de l'école
    public function index(Request $request)
    {
        $utilisateurs = User::where('ecole_id', $request->user()->ecole_id)
            ->where('id', '!=', $request->user()->id)
            ->with('permissions')
            ->get();

        return response()->json($utilisateurs);
    }

    // Créer un utilisateur
    public function creer(Request $request)
    {
        $request->validate([
            'nom'   => 'required|string|max:191',
            'email' => 'required|email|unique:users,email',
            'role'  => 'required|in:censeur,secretaire,enseignant',
        ]);

        // Mot de passe temporaire
        $motDePasse = Str::random(8);

        $utilisateur = User::create([
            'name'                => $request->nom,
            'email'               => $request->email,
            'password'            => bcrypt($motDePasse),
            'role'                => $request->role,
            'ecole_id'            => $request->user()->ecole_id,
            'mot_de_passe_change' => false,
        ]);

        return response()->json([
            'message'        => 'Utilisateur créé avec succès',
            'utilisateur'    => $utilisateur,
            'mot_de_passe'   => $motDePasse, // À envoyer à l'utilisateur
        ], 201);
    }

    // Modifier le rôle
    public function modifierRole(Request $request, $id)
    {
        $request->validate([
            'role' => 'required|in:censeur,secretaire,enseignant',
        ]);

        $utilisateur = User::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $utilisateur->update(['role' => $request->role]);

        return response()->json(['message' => 'Rôle mis à jour']);
    }

    // Modifier les permissions modules
    public function modifierModules(Request $request, $id)
    {
        $request->validate([
            'permissions'              => 'required|array',
            'permissions.*.nom_module' => 'required|string',
            'permissions.*.autorise'   => 'required|boolean',
        ]);

        $utilisateur = User::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        foreach ($request->permissions as $perm) {
            PermissionModule::updateOrCreate(
                [
                    'utilisateur_id' => $utilisateur->id,
                    'nom_module'     => $perm['nom_module'],
                ],
                ['autorise' => $perm['autorise']]
            );
        }

        return response()->json(['message' => 'Permissions mises à jour']);
    }
}