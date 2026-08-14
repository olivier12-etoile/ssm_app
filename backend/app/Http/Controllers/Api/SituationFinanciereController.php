<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\Eleve;
use App\Models\Paiement;
use App\Services\FraisCalculService;
use App\Services\SituationFinanciereEleveService;
use Illuminate\Http\Request;

class SituationFinanciereController extends Controller
{
    public function __construct(
        private FraisCalculService $fraisCalcul,
        private SituationFinanciereEleveService $situationEleveService
    ) {
    }

    // GET /eleves/{id}/situation-financiere
    public function show(Request $request, $eleveId)
    {
        $ecoleId = $request->user()->ecole_id;

        $eleve = Eleve::where('id', $eleveId)->where('ecole_id', $ecoleId)->firstOrFail();

        $anneeScolaireId = $request->integer('annee_scolaire_id')
            ?: optional(AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->first())->id;

        if (!$anneeScolaireId) {
            return response()->json([
                'message' => "Aucune année scolaire active. Précisez annee_scolaire_id.",
            ], 422);
        }

        $situation = $this->fraisCalcul->situationEleve($eleve, $anneeScolaireId);

        $historique = Paiement::where('eleve_id', $eleve->id)
            ->whereHas('fraisScolaire', fn($q) => $q->where('annee_scolaire_id', $anneeScolaireId))
            ->with(['fraisScolaire:id,nom', 'echeance:id,libelle'])
            ->orderByDesc('date_paiement')
            ->orderByDesc('id')
            ->get();

        return response()->json([
            'eleve' => [
                'id'        => $eleve->id,
                'nom'       => $eleve->nom,
                'prenom'    => $eleve->prenom,
                'matricule' => $eleve->matricule,
            ],
            'annee_scolaire_id' => $anneeScolaireId,
            'frais'             => $situation['frais'],
            'montant_attendu'   => $situation['montant_attendu'],
            'montant_paye'      => $situation['montant_paye'],
            'reste_a_payer'     => $situation['reste_a_payer'],
            'historique_paiements' => $historique,
        ]);
    }

    // GET /paiements/eleves/{id}/statut-financier
    public function statutFinancier(Request $request, $eleveId)
    {
        $ecoleId = $request->user()->ecole_id;

        $eleve = Eleve::where('id', $eleveId)->where('ecole_id', $ecoleId)->firstOrFail();

        return response()->json($this->situationEleveService->statutFinancier($eleve->id));
    }
}
