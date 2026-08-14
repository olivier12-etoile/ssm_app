<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ParametreValidationNote;
use Illuminate\Http\Request;

/**
 * Configuration du workflow de validation des notes (une ligne par école).
 *
 * À lire par ValidationNoteController (module Notes & Évaluations déjà
 * existant) :
 * - roles_autorises_validation → ValidationNoteController::autoriserGestionnaire()
 *   (private, appelée par enAttente/detail/valider/rejeter) fait aujourd'hui
 *   abort_unless(in_array($role, ['directeur', 'censeur']), ...) en dur. Elle
 *   doit être remplacée par un appel à
 *   ParametreValidationNote::where('ecole_id', $ecoleId)->first()?->rolesAutorisesOuDefaut()
 *   pour respecter ce paramètre.
 * - modification_apres_validation / verrouillage_auto_cloture_periode →
 *   concernent VerrouillageNote (créé par
 *   ValidationNoteController::valider()) et PeriodeAcademiqueController::fermer(),
 *   qui verrouillent aujourd'hui sans consulter ce réglage.
 * - validation_obligatoire → SoumissionController::soumettre() (statut
 *   passe à en_attente_validation) devrait, si false, permettre à une
 *   saisie soumise de passer directement à "validee" sans validation
 *   manuelle.
 */
class ParametreValidationNoteController extends Controller
{
    // GET /parametres/validation-notes
    public function show(Request $request)
    {
        $parametre = ParametreValidationNote::firstOrCreate(['ecole_id' => $request->user()->ecole_id]);

        return response()->json(['parametre' => $parametre]);
    }

    // PUT /parametres/validation-notes (directeur uniquement)
    public function update(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut modifier la configuration de validation des notes.',
            ], 403);
        }

        $data = $request->validate([
            'validation_obligatoire'             => 'sometimes|boolean',
            'roles_autorises_validation'          => 'sometimes|array|min:1',
            'roles_autorises_validation.*'        => 'in:directeur,censeur',
            'modification_apres_validation'       => 'sometimes|boolean',
            'verrouillage_auto_cloture_periode'   => 'sometimes|boolean',
        ]);

        $parametre = ParametreValidationNote::firstOrCreate(['ecole_id' => $request->user()->ecole_id]);
        $parametre->update($data);

        return response()->json([
            'message'   => 'Configuration de validation des notes mise à jour avec succès',
            'parametre' => $parametre->fresh(),
        ]);
    }
}
