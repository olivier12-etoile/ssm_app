<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\StatistiqueGeneraleService;
use Illuminate\Http\Request;

class DashboardStatistiqueController extends Controller
{
    public function __construct(private StatistiqueGeneraleService $statistiqueGenerale)
    {
    }

    // GET /statistiques/dashboard/general
    public function general(Request $request)
    {
        $request->validate([
            'annee_scolaire_id' => 'required|integer|exists:annees_academiques,id',
            'periode_id'        => 'nullable|integer|exists:periodes_academiques,id',
        ]);

        $dashboard = $this->statistiqueGenerale->dashboardGeneral(
            (int) $request->annee_scolaire_id,
            $request->filled('periode_id') ? (int) $request->periode_id : null
        );

        return response()->json($dashboard);
    }

    // POST /statistiques/dashboard/snapshot (directeur uniquement)
    public function snapshot(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut créer un instantané statistique.',
            ], 403);
        }

        $request->validate([
            'annee_scolaire_id' => 'required|integer|exists:annees_academiques,id',
            'type'              => 'required|in:effectifs,financier,pedagogique',
        ]);

        $instantane = $this->statistiqueGenerale->creerSnapshot(
            (int) $request->annee_scolaire_id,
            $request->type
        );

        return response()->json([
            'message'    => 'Instantané créé avec succès.',
            'instantane' => $instantane,
        ], 201);
    }

    // GET /statistiques/dashboard/comparaison
    public function comparaison(Request $request)
    {
        $request->validate([
            'annee1' => 'required|integer|exists:annees_academiques,id',
            'annee2' => 'required|integer|exists:annees_academiques,id',
            'type'   => 'required|in:effectifs,financier,pedagogique',
        ]);

        $comparaison = $this->statistiqueGenerale->comparerAnnees(
            (int) $request->annee1,
            (int) $request->annee2,
            $request->type
        );

        return response()->json($comparaison);
    }
}
