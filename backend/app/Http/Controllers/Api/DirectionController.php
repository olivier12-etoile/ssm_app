<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class DirectionController extends Controller
{
    // GET /parametres/direction
    public function show(Request $request)
    {
        $ecole = $request->user()->ecole;

        return response()->json([
            'direction' => [
                'directeur_nom'       => $ecole->directeur_nom,
                'directeur_prenom'    => $ecole->directeur_prenom,
                'directeur_fonction'  => $ecole->directeur_fonction,
                'directeur_telephone' => $ecole->directeur_telephone,
                'directeur_email'     => $ecole->directeur_email,
            ],
        ]);
    }

    // PUT /parametres/direction (directeur uniquement)
    public function update(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut modifier ces informations.',
            ], 403);
        }

        $data = $request->validate([
            'directeur_nom'       => 'sometimes|string|max:191',
            'directeur_prenom'    => 'nullable|string|max:191',
            'directeur_fonction'  => 'nullable|string|max:191',
            'directeur_telephone' => 'nullable|string|max:20|regex:/^(\+228)?[\s\-]?[0-9][0-9\s\-]{6,17}$/',
            'directeur_email'     => 'nullable|email|max:191',
        ]);

        $ecole = $request->user()->ecole;
        $ecole->update($data);

        return response()->json([
            'message'   => 'Informations de la direction mises à jour avec succès',
            'direction' => $ecole->fresh(),
        ]);
    }
}
