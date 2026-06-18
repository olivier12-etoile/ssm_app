<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class ProfilController extends Controller
{
    // Voir son profil
    public function index(Request $request)
    {
        $utilisateur = $request->user()->load('ecole');

        return response()->json([
            'id'                  => $utilisateur->id,
            'nom'                 => $utilisateur->name,
            'email'               => $utilisateur->email,
            'role'                => $utilisateur->role,
            'mot_de_passe_change' => $utilisateur->mot_de_passe_change,
            'ecole'               => [
                'nom'              => $utilisateur->ecole->nom,
                'code_ecole'       => $utilisateur->ecole->code_ecole,
                'couleur_primaire' => $utilisateur->ecole->couleur_primaire,
                'telephone'        => $utilisateur->ecole->telephone,
                'adresse'          => $utilisateur->ecole->adresse,
            ],
        ]);
    }

    // Modifier son nom
    public function modifier(Request $request)
    {
        $request->validate([
            'nom' => 'required|string|max:191',
        ]);

        $request->user()->update(['name' => $request->nom]);

        return response()->json(['message' => 'Profil mis à jour']);
    }

    // Changer mot de passe
    public function changerMotDePasse(Request $request)
    {
        $request->validate([
            'ancien_mot_de_passe'              => 'required',
            'nouveau_mot_de_passe'             => 'required|min:6|confirmed',
        ]);

        if (!Hash::check($request->ancien_mot_de_passe, $request->user()->password)) {
            return response()->json([
                'message' => 'Ancien mot de passe incorrect'
            ], 401);
        }

        $request->user()->update([
            'password'            => bcrypt($request->nouveau_mot_de_passe),
            'mot_de_passe_change' => true,
        ]);

        return response()->json(['message' => 'Mot de passe changé avec succès']);
    }
}