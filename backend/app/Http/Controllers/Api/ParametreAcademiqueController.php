<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\ParametreAcademique;
use Illuminate\Http\Request;

/**
 * Paramètres pédagogiques globaux (une ligne par école).
 *
 * Modules qui doivent lire ces réglages :
 * - bareme_note_max → NoteController::store()/storeBulk()/update() valident
 *   aujourd'hui la note avec un "max:20" en dur (voir lignes 33, 89, 161 de
 *   NoteController). Ils doivent utiliser
 *   ParametreAcademique::where('ecole_id', ...)->value('bareme_note_max') ?? 20
 *   à la place.
 * - coefficients_par_matiere/classe/niveau, mode_calcul_moyenne_matiere →
 *   NoteCalculService (moyenneMatiere/moyenneEleve) applique aujourd'hui une
 *   "moyenne simple des deux" (devoir + composition) codée en dur — c'est
 *   le point d'entrée à adapter le jour où mode_calcul_moyenne_matiere
 *   passera à "ponderee".
 */
class ParametreAcademiqueController extends Controller
{
    // GET /parametres/academique
    public function show(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $parametre = ParametreAcademique::firstOrCreate(['ecole_id' => $ecoleId]);

        return response()->json([
            'parametre' => $parametre,
            // type_decoupage n'est PAS stocké dans parametres_academiques :
            // c'est annees_academiques.type_periodes (module Années &
            // Périodes) qui reste la seule source de vérité, pour éviter
            // que les deux valeurs divergent. On l'expose ici en lecture
            // pour que l'écran "Paramètres académiques" puisse l'afficher
            // à côté du reste ; update() ci-dessous sait aussi l'écrire.
            'type_decoupage_annee_active' => AnneeAcademique::where('ecole_id', $ecoleId)
                ->where('statut', 'active')
                ->value('type_periodes'),
        ]);
    }

    // PUT /parametres/academique (directeur uniquement)
    public function update(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut modifier les paramètres académiques.',
            ], 403);
        }

        $ecoleId = $request->user()->ecole_id;

        $data = $request->validate([
            'type_decoupage'               => 'sometimes|in:trimestres,semestres',
            'bareme_note_max'               => 'sometimes|integer|min:10|max:100',
            'coefficients_par_matiere'      => 'sometimes|boolean',
            'coefficients_par_classe'       => 'sometimes|boolean',
            'coefficients_par_niveau'       => 'sometimes|boolean',
            'mode_calcul_moyenne_matiere'   => 'sometimes|in:simple,ponderee',
        ]);

        $avertissements = [];

        // type_decoupage : écrit sur l'année active (annees_academiques),
        // pas sur parametres_academiques — voir le commentaire de classe.
        if (array_key_exists('type_decoupage', $data)) {
            $anneeActive = AnneeAcademique::where('ecole_id', $ecoleId)
                ->where('statut', 'active')
                ->first();

            if (!$anneeActive) {
                return response()->json([
                    'message' => "Aucune année scolaire active : activez une année avant de définir son découpage.",
                ], 422);
            }

            if ($anneeActive->type_periodes !== $data['type_decoupage']) {
                if ($anneeActive->periodes()->exists()) {
                    return response()->json([
                        'message' => 'Impossible de changer le découpage : des périodes existent déjà pour cette année scolaire.',
                    ], 422);
                }

                $anneeActive->update(['type_periodes' => $data['type_decoupage']]);
            }
        }
        unset($data['type_decoupage']);

        if (array_key_exists('bareme_note_max', $data)) {
            $avertissements[] = "Le nouveau barème ne s'applique qu'aux futures saisies de notes : les notes déjà enregistrées ne sont pas recalculées rétroactivement.";
        }

        $parametre = ParametreAcademique::firstOrCreate(['ecole_id' => $ecoleId]);
        $parametre->update($data);

        return response()->json([
            'message'        => 'Paramètres académiques mis à jour avec succès',
            'parametre'      => $parametre->fresh(),
            'avertissements' => $avertissements,
        ]);
    }
}
