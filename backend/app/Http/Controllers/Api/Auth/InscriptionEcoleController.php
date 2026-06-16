<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Models\Ecole;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class InscriptionEcoleController extends Controller
{
    public function inscrire(Request $request)
    {
        $request->validate([
            'nom_ecole'  => 'required|string|max:191',
            'email'      => 'required|email|unique:users,email',
            'password'   => 'required|min:6',
            'telephone'  => 'nullable|string|max:20',
            'adresse'    => 'nullable|string|max:191',
        ]);

        // Générer un code école unique
        do {
            $code = strtoupper(Str::random(6));
        } while (Ecole::where('code_ecole', $code)->exists());

        // Créer l'école
        $ecole = Ecole::create([
            'nom'               => $request->nom_ecole,
            'code_ecole'        => $code,
            'telephone'         => $request->telephone,
            'adresse'           => $request->adresse,
            'statut_abonnement' => 'essai',
        ]);

        // Créer le compte Directeur
        $utilisateur = User::create([
            'name'                => $request->nom_ecole,
            'email'               => $request->email,
            'password'            => bcrypt($request->password),
            'role'                => 'directeur',
            'ecole_id'            => $ecole->id,
            'mot_de_passe_change' => true,
        ]);

        $token = $utilisateur->createToken('ssm_token')->plainTextToken;

        return response()->json([
            'message'    => 'École créée avec succès',
            'code_ecole' => $code,
            'token'      => $token,
            'utilisateur' => [
                'id'    => $utilisateur->id,
                'nom'   => $utilisateur->name,
                'email' => $utilisateur->email,
                'role'  => $utilisateur->role,
            ],
        ], 201);
    }
}