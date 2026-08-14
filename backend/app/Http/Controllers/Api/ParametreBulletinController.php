<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ParametreBulletin;
use Illuminate\Http\Request;

/**
 * Configuration d'affichage des bulletins (une ligne par école).
 *
 * À lire par le générateur de bulletin PDF (module Bulletins, prochaine
 * phase) : avant de construire la vue, charger
 * ParametreBulletin::where('ecole_id', $ecoleId)->first() et conditionner
 * chaque bloc du template blade (logo, matricule, effectif, coefficients,
 * rang, appréciations, absences, retards, décision du conseil, signature,
 * cachet) sur le switch correspondant, et choisir le template selon
 * modele_bulletin (standard|compact|detaille). Aujourd'hui
 * BulletinController::generer()/parClasse() ne consultent pas encore ces
 * réglages.
 */
class ParametreBulletinController extends Controller
{
    // GET /parametres/bulletins
    public function show(Request $request)
    {
        $parametre = ParametreBulletin::firstOrCreate(['ecole_id' => $request->user()->ecole_id]);

        return response()->json(['parametre' => $parametre]);
    }

    // PUT /parametres/bulletins (directeur uniquement)
    public function update(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut modifier la configuration des bulletins.',
            ], 403);
        }

        $data = $request->validate([
            'afficher_logo'                => 'sometimes|boolean',
            'afficher_matricule'           => 'sometimes|boolean',
            'afficher_effectif'            => 'sometimes|boolean',
            'afficher_coefficients'        => 'sometimes|boolean',
            'afficher_rang'                => 'sometimes|boolean',
            'afficher_appreciations'       => 'sometimes|boolean',
            'afficher_absences'            => 'sometimes|boolean',
            'afficher_retards'             => 'sometimes|boolean',
            'afficher_decision_conseil'    => 'sometimes|boolean',
            'afficher_signature_directeur' => 'sometimes|boolean',
            'afficher_cachet'              => 'sometimes|boolean',
            'modele_bulletin'              => 'sometimes|in:standard,compact,detaille',
        ]);

        $parametre = ParametreBulletin::firstOrCreate(['ecole_id' => $request->user()->ecole_id]);
        $parametre->update($data);

        return response()->json([
            'message'   => 'Configuration des bulletins mise à jour avec succès',
            'parametre' => $parametre->fresh(),
        ]);
    }
}
