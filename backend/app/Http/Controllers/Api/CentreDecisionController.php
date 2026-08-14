<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\CentreDecisionService;
use Illuminate\Http\Request;

class CentreDecisionController extends Controller
{
    public function __construct(private CentreDecisionService $service)
    {
    }

    // GET /statistiques/centre-decision/alertes?annee_scolaire_id=&periode_id=&seuil_paiement_retard=
    public function alertes(Request $request)
    {
        $request->validate([
            'annee_scolaire_id'     => 'required|integer',
            'periode_id'            => 'required|integer',
            'seuil_paiement_retard' => 'nullable|integer',
        ]);

        $seuil = $request->filled('seuil_paiement_retard') ? (int) $request->seuil_paiement_retard : 20;

        $alertes = $this->service->genererAlertes(
            $request,
            (int) $request->annee_scolaire_id,
            (int) $request->periode_id,
            $seuil
        );

        return response()->json([
            'total'   => count($alertes),
            'alertes' => $alertes,
        ]);
    }
}
