<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class InformationsEtablissementController extends Controller
{
    // GET /parametres/etablissement
    public function show(Request $request)
    {
        $ecole = $request->user()->ecole;

        return response()->json([
            'etablissement' => [
                'nom'                 => $ecole->nom,
                'nom_court'           => $ecole->nom_court,
                'sigle'               => $ecole->sigle,
                'code_ecole'          => $ecole->code_ecole,
                'type_etablissement'  => $ecole->type_etablissement,
                'adresse'             => $ecole->adresse,
                'ville'               => $ecole->ville,
                'region'              => $ecole->region,
                'pays'                => $ecole->pays,
                'telephone'           => $ecole->telephone,
                'email'               => $ecole->email,
                'site_web'            => $ecole->site_web,
                'devise'              => $ecole->devise,
                'annee_creation'      => $ecole->annee_creation,
            ],
        ]);
    }

    // PUT /parametres/etablissement (directeur uniquement)
    public function update(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut modifier les informations de l\'établissement.',
            ], 403);
        }

        $data = $request->validate([
            'nom'                => 'sometimes|string|max:191',
            'nom_court'          => 'nullable|string|max:100',
            'sigle'              => 'nullable|string|max:20',
            'type_etablissement' => 'sometimes|in:primaire,college,lycee,complexe',
            'adresse'            => 'nullable|string|max:191',
            'ville'              => 'nullable|string|max:100',
            'region'             => 'nullable|string|max:100',
            'pays'               => 'nullable|string|max:100',
            // Numéro togolais (8 chiffres, indicatif +228 optionnel) si
            // renseigné : on tolère espaces/tirets, la contrainte reste
            // souple pour ne pas bloquer un format déjà saisi différemment.
            'telephone'          => 'nullable|string|max:20|regex:/^(\+228)?[\s\-]?[0-9][0-9\s\-]{6,17}$/',
            'email'              => 'nullable|email|max:191',
            'site_web'           => 'nullable|url|max:191',
            'devise'             => 'nullable|string|max:10',
            'annee_creation'     => 'nullable|integer|min:1900|max:' . (int) date('Y'),
        ]);

        $ecole = $request->user()->ecole;
        $ecole->update($data);

        return response()->json([
            'message'       => 'Informations de l\'établissement mises à jour avec succès',
            'etablissement' => $ecole->fresh(),
        ]);
    }
}
