<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ParametreMatiere;
use Illuminate\Http\Request;

/**
 * Réglages par défaut pour la gestion des matières (une ligne par école).
 *
 * À lire par MatiereController::store()/update() et ClasseMatiereController
 * (module Matières déjà existant) :
 * - systeme_coefficients → si "fixe", MatiereController devrait refuser la
 *   saisie d'un coefficient différent de matieres.coefficient au niveau
 *   d'une classe (ClasseMatiereController::enregistrer()) ; si "variable",
 *   le comportement actuel (coefficient libre par classe_matiere) est déjà
 *   correct.
 * - matieres_facultatives_autorisees → MatiereController::store() n'a pas
 *   aujourd'hui de notion de matière facultative ; ce paramètre gate
 *   l'apparition d'un futur champ 'facultative' sur matieres.
 */
class ParametreMatiereController extends Controller
{
    // GET /parametres/matieres
    public function show(Request $request)
    {
        $parametre = ParametreMatiere::firstOrCreate(['ecole_id' => $request->user()->ecole_id]);

        return response()->json(['parametre' => $parametre]);
    }

    // PUT /parametres/matieres (directeur uniquement)
    public function update(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut modifier ces paramètres.',
            ], 403);
        }

        $data = $request->validate([
            'systeme_coefficients'              => 'sometimes|in:fixe,variable',
            'matieres_facultatives_autorisees'  => 'sometimes|boolean',
        ]);

        $parametre = ParametreMatiere::firstOrCreate(['ecole_id' => $request->user()->ecole_id]);
        $parametre->update($data);

        return response()->json([
            'message'   => 'Paramètres des matières mis à jour avec succès',
            'parametre' => $parametre->fresh(),
        ]);
    }
}
