<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Caisse;
use App\Services\CaisseService;
use Illuminate\Http\Request;

class CaisseController extends Controller
{
    public function __construct(private CaisseService $caisseService)
    {
    }

    // GET /paiements/caisses
    public function index(Request $request)
    {
        $caisses = Caisse::orderBy('nom')->get();

        return response()->json($caisses);
    }

    // POST /paiements/caisses
    public function store(Request $request)
    {
        $data = $request->validate([
            'nom'   => 'required|string|max:255',
            'actif' => 'nullable|boolean',
        ]);

        $caisse = Caisse::create([
            'nom'   => $data['nom'],
            'actif' => $data['actif'] ?? true,
        ]);

        return response()->json([
            'message' => 'Caisse créée avec succès',
            'caisse'  => $caisse,
        ], 201);
    }

    // POST /paiements/caisses/ouvrir
    public function ouvrir(Request $request)
    {
        $data = $request->validate([
            'caisse_id'       => 'required|integer',
            'montant_initial' => 'required|numeric|min:0',
        ]);

        try {
            $session = $this->caisseService->ouvrir(
                $data['caisse_id'],
                (float) $data['montant_initial'],
                $request->user()->id
            );
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json([
            'message' => 'Session de caisse ouverte avec succès',
            'session' => $session->load(['caisse', 'ouvertPar']),
        ], 201);
    }

    // POST /paiements/caisses/fermer
    public function fermer(Request $request)
    {
        $data = $request->validate([
            'session_id'  => 'required|integer',
            'montant_reel'=> 'required|numeric|min:0',
            'observation' => 'nullable|string',
        ]);

        try {
            $session = $this->caisseService->fermer(
                $data['session_id'],
                (float) $data['montant_reel'],
                $data['observation'] ?? null,
                $request->user()->id
            );
        } catch (\InvalidArgumentException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json([
            'message' => 'Session de caisse fermée avec succès',
            'session' => $session->load(['caisse', 'ouvertPar', 'fermePar']),
        ]);
    }

    // GET /paiements/caisses/{id}/session-active
    public function sessionActive(Request $request, $id)
    {
        $session = $this->caisseService->sessionActive((int) $id);

        return response()->json([
            'session_active' => $session?->load(['caisse', 'ouvertPar']),
        ]);
    }

    // GET /paiements/caisses/{id}/historique
    public function historique(Request $request, $id)
    {
        $sessions = $this->caisseService->historiqueSessions(
            (int) $id,
            $request->query('date_debut'),
            $request->query('date_fin')
        );

        return response()->json($sessions->load(['ouvertPar', 'fermePar']));
    }
}
