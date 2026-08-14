<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ParametreClasse;
use Illuminate\Http\Request;

/**
 * Réglages par défaut à la création d'une classe (une ligne par école).
 *
 * À lire par ClasseController::store() (module Classes déjà existant) :
 * - effectif_max_par_classe → valeur par défaut de 'capacite_max' quand le
 *   directeur n'en saisit pas (aujourd'hui la colonne classes.capacite_max
 *   a son propre défaut MySQL à 50, indépendant de ce paramètre).
 * - format_code_classe → n'est pas encore utilisé : ClasseController::store()
 *   construit 'nom' à partir de niveau/serie/indice concaténés en dur ; ce
 *   gabarit servirait à généraliser cette construction.
 */
class ParametreClasseController extends Controller
{
    // GET /parametres/classes
    public function show(Request $request)
    {
        $parametre = ParametreClasse::firstOrCreate(['ecole_id' => $request->user()->ecole_id]);

        return response()->json(['parametre' => $parametre]);
    }

    // PUT /parametres/classes (directeur uniquement)
    public function update(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut modifier ces paramètres.',
            ], 403);
        }

        $data = $request->validate([
            'effectif_max_par_classe' => 'sometimes|integer|min:1',
            'format_code_classe'      => 'sometimes|string|max:50',
        ]);

        $parametre = ParametreClasse::firstOrCreate(['ecole_id' => $request->user()->ecole_id]);
        $parametre->update($data);

        return response()->json([
            'message'   => 'Paramètres des classes mis à jour avec succès',
            'parametre' => $parametre->fresh(),
        ]);
    }
}
