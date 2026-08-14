<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ParametreFrais;
use Illuminate\Http\Request;

/**
 * Réglages financiers globaux (une ligne par école).
 *
 * À lire par FraisCalculService (module Frais Scolaires déjà existant) :
 * - seuil_jours_retard_non_en_regle → FraisCalculService::statutFrais()
 *   renvoie 'impaye' dès que montantPaye < montantDu, sans tenir compte
 *   d'un délai de grâce, et
 *   StatistiquePaiementService::elevesNonEnRegleListe() (filtre
 *   `reste_a_payer > 0`, ligne ~150) considère un élève "non en règle" dès
 *   le premier centime dû. Pour appliquer ce seuil, ce filtre doit devenir :
 *   reste_a_payer > 0 ET now()->diffInDays(frais.date_limite) > seuil_jours_retard_non_en_regle
 *   (le frais le plus ancien impayé donnant la date de référence).
 * - penalites_actives / montant_penalite_retard → aucun calcul de pénalité
 *   n'existe aujourd'hui dans FraisCalculService::resteAPayer() ; ce serait
 *   un montant supplémentaire à ajouter à montantDuParEleve() une fois le
 *   seuil de jours dépassé.
 * - paiement_partiel_autorise → PaiementController::store() n'impose
 *   aujourd'hui aucune contrainte de montant minimal (paiement partiel déjà
 *   possible de fait) ; si false, il devrait exiger montant >= resteAPayer().
 * - nombre_tranches_defaut → à utiliser comme valeur pré-remplie côté
 *   frontend lors de la création d'un FraisScolaire avec échéances.
 * - devise → PaiementController, AnneeAcademiqueController, EleveController
 *   et MessageTemplateService affichent "FCFA" en dur ; à terme ces
 *   affichages devraient lire ce paramètre.
 */
class ParametreFraisController extends Controller
{
    // GET /parametres/frais
    public function show(Request $request)
    {
        $parametre = ParametreFrais::firstOrCreate(['ecole_id' => $request->user()->ecole_id]);

        return response()->json(['parametre' => $parametre]);
    }

    // PUT /parametres/frais (directeur uniquement)
    public function update(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut modifier les paramètres financiers.',
            ], 403);
        }

        $data = $request->validate([
            'devise'                           => 'sometimes|string|max:10',
            'nombre_tranches_defaut'           => 'sometimes|integer|min:1|max:12',
            'penalites_actives'                => 'sometimes|boolean',
            'montant_penalite_retard'          => 'nullable|numeric|min:0',
            'paiement_partiel_autorise'        => 'sometimes|boolean',
            'seuil_jours_retard_non_en_regle'  => 'sometimes|integer|min:0',
        ]);

        if (($data['penalites_actives'] ?? false) && empty($data['montant_penalite_retard'])) {
            $parametreExistant = ParametreFrais::where('ecole_id', $request->user()->ecole_id)->first();
            if (!$parametreExistant?->montant_penalite_retard) {
                return response()->json([
                    'message' => "Un montant de pénalité de retard est requis pour activer les pénalités.",
                ], 422);
            }
        }

        $parametre = ParametreFrais::firstOrCreate(['ecole_id' => $request->user()->ecole_id]);
        $parametre->update($data);

        return response()->json([
            'message'   => 'Paramètres financiers mis à jour avec succès',
            'parametre' => $parametre->fresh(),
        ]);
    }
}
