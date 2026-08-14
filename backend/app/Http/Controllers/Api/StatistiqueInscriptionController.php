<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\StatistiqueInscriptionService;
use Illuminate\Http\Request;

class StatistiqueInscriptionController extends Controller
{
    public function __construct(private StatistiqueInscriptionService $service)
    {
    }

    // GET /statistiques/inscriptions/par-annee
    public function parAnnee(Request $request)
    {
        return response()->json([
            'annees' => $this->service->parAnnee($request->user()->ecole_id),
        ]);
    }

    // GET /statistiques/inscriptions/par-niveau?annee_scolaire_id=
    public function parNiveau(Request $request)
    {
        $request->validate(['annee_scolaire_id' => 'required|integer']);

        return response()->json([
            'niveaux' => $this->service->parNiveau($request->user()->ecole_id, (int) $request->annee_scolaire_id),
        ]);
    }

    // GET /statistiques/inscriptions/par-classe?annee_scolaire_id=
    public function parClasse(Request $request)
    {
        $request->validate(['annee_scolaire_id' => 'required|integer']);

        return response()->json([
            'classes' => $this->service->parClasse($request->user()->ecole_id, (int) $request->annee_scolaire_id),
        ]);
    }

    // GET /statistiques/inscriptions/par-sexe?annee_scolaire_id=
    public function parSexe(Request $request)
    {
        $request->validate(['annee_scolaire_id' => 'required|integer']);

        return response()->json(
            $this->service->parSexe($request->user()->ecole_id, (int) $request->annee_scolaire_id)
        );
    }

    // GET /statistiques/inscriptions/evolution?nombre_annees=
    public function evolution(Request $request)
    {
        $nombreAnnees = $request->filled('nombre_annees') ? (int) $request->nombre_annees : 5;

        return response()->json(
            $this->service->evolutionEffectifs($request->user()->ecole_id, $nombreAnnees)
        );
    }
}
