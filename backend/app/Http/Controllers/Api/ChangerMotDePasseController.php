<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class ChangerMotDePasseController extends Controller
{
    public function changer(Request $request)
    {
        $request->validate([
            'ancien_mot_de_passe' => 'required',
            'nouveau_mot_de_passe' => 'required|min:6|confirmed',
        ]);

        $utilisateur = $request->user();

        // Vérifier l'ancien mot de passe
        if (!Hash::check($request->ancien_mot_de_passe, $utilisateur->password)) {
            return response()->json([
                'message' => 'Ancien mot de passe incorrect'
            ], 401);
        }

        // Mettre à jour
        $utilisateur->update([
            'password'            => bcrypt($request->nouveau_mot_de_passe),
            'mot_de_passe_change' => true,
        ]);

        return response()->json([
            'message' => 'Mot de passe changé avec succès'
        ]);
    }
}