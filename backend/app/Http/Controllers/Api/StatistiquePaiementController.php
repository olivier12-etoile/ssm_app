<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\StatistiquePaiementService;
use Illuminate\Http\Request;

class StatistiquePaiementController extends Controller
{
    public function __construct(private StatistiquePaiementService $service)
    {
    }

    // GET /statistiques/paiements/par-classe?annee_scolaire_id=
    public function parClasse(Request $request)
    {
        $request->validate(['annee_scolaire_id' => 'required|integer']);

        return response()->json([
            'classes' => $this->service->parClasse($request->user()->ecole_id, (int) $request->annee_scolaire_id),
        ]);
    }

    // GET /statistiques/paiements/par-niveau?annee_scolaire_id=
    public function parNiveau(Request $request)
    {
        $request->validate(['annee_scolaire_id' => 'required|integer']);

        return response()->json([
            'niveaux' => $this->service->parNiveau($request->user()->ecole_id, (int) $request->annee_scolaire_id),
        ]);
    }

    // GET /statistiques/paiements/par-mois?annee_scolaire_id=
    public function parMois(Request $request)
    {
        $request->validate(['annee_scolaire_id' => 'required|integer']);

        return response()->json([
            'mois' => $this->service->parMois($request->user()->ecole_id, (int) $request->annee_scolaire_id),
        ]);
    }

    // GET /statistiques/paiements/eleves-non-en-regle?annee_scolaire_id=&classe_id=&niveau=&montant_min=
    public function elevesNonEnRegle(Request $request)
    {
        $request->validate([
            'annee_scolaire_id' => 'nullable|integer',
            'classe_id'         => 'nullable|integer',
            'niveau'            => 'nullable|string',
            'montant_min'       => 'nullable|numeric',
        ]);

        $eleves = $this->service->elevesNonEnRegle($request);

        return response()->json([
            'total'  => count($eleves),
            'eleves' => $eleves,
        ]);
    }
}
