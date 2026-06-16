<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class ConnexionController extends Controller
{
    public function connecter(Request $request)
    {
        $request->validate([
            'email'      => 'required|email',
            'password'   => 'required',
            'code_ecole' => 'required|string',
        ]);

        // Vérifier l'utilisateur
        $utilisateur = User::where('email', $request->email)->first();

        if (!$utilisateur || !Hash::check($request->password, $utilisateur->password)) {
            return response()->json([
                'message' => 'Email ou mot de passe incorrect'
            ], 401);
        }

        // Vérifier le code école
        if ($utilisateur->ecole->code_ecole !== strtoupper($request->code_ecole)) {
            return response()->json([
                'message' => 'Code école incorrect'
            ], 401);
        }

        // Supprimer les anciens tokens
        $utilisateur->tokens()->delete();

        $token = $utilisateur->createToken('ssm_token')->plainTextToken;

        return response()->json([
            'token' => $token,
            'utilisateur' => [
                'id'                  => $utilisateur->id,
                'nom'                 => $utilisateur->name,
                'email'               => $utilisateur->email,
                'role'                => $utilisateur->role,
                'ecole_id'            => $utilisateur->ecole_id,
                'code_ecole'          => $utilisateur->ecole->code_ecole,
                'couleur_primaire'    => $utilisateur->ecole->couleur_primaire,
                'couleur_secondaire'  => $utilisateur->ecole->couleur_secondaire,
                'mot_de_passe_change' => $utilisateur->mot_de_passe_change,
            ],
        ]);
    }

    public function deconnecter(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Déconnecté avec succès'
        ]);
    }

    public function moi(Request $request)
    {
        $utilisateur = $request->user()->load('ecole');

        return response()->json([
            'id'                  => $utilisateur->id,
            'nom'                 => $utilisateur->name,
            'email'               => $utilisateur->email,
            'role'                => $utilisateur->role,
            'ecole_id'            => $utilisateur->ecole_id,
            'code_ecole'          => $utilisateur->ecole->code_ecole,
            'couleur_primaire'    => $utilisateur->ecole->couleur_primaire,
            'couleur_secondaire'  => $utilisateur->ecole->couleur_secondaire,
            'mot_de_passe_change' => $utilisateur->mot_de_passe_change,
        ]);
    }
}