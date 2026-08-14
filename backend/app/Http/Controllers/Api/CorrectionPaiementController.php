<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CorrectionPaiement;
use App\Models\JournalOperationFrais;
use App\Models\Paiement;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CorrectionPaiementController extends Controller
{
    // POST /paiements/corrections
    public function store(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut corriger un paiement.',
            ], 403);
        }

        $data = $request->validate([
            'paiement_id'           => 'required|integer',
            'nouveau_montant'       => 'nullable|numeric|min:1',
            'nouveau_mode_paiement' => 'nullable|in:especes,moov_money,wave,virement,cheque',
            'motif'                 => 'required|string|max:500',
        ]);

        if (empty($data['nouveau_montant']) && empty($data['nouveau_mode_paiement'])) {
            return response()->json([
                'message' => 'Précisez un nouveau montant et/ou un nouveau mode de paiement.',
            ], 422);
        }

        $paiement = Paiement::findOrFail($data['paiement_id']);

        $correction = DB::transaction(function () use ($paiement, $data, $request) {
            $correction = CorrectionPaiement::create([
                'paiement_id'            => $paiement->id,
                'corrige_par'            => $request->user()->id,
                'ancien_montant'         => $paiement->montant,
                'nouveau_montant'        => $data['nouveau_montant'] ?? $paiement->montant,
                'ancien_mode_paiement'   => $paiement->mode_paiement,
                'nouveau_mode_paiement'  => $data['nouveau_mode_paiement'] ?? null,
                'motif'                  => $data['motif'],
            ]);

            $paiement->update([
                'montant'       => $data['nouveau_montant'] ?? $paiement->montant,
                'mode_paiement' => $data['nouveau_mode_paiement'] ?? $paiement->mode_paiement,
            ]);

            JournalOperationFrais::create([
                'user_id'     => $request->user()->id,
                'action'      => 'paiement_corrige',
                'description' => "Paiement {$paiement->numero_recu} corrigé — Motif : {$data['motif']}",
                'paiement_id' => $paiement->id,
            ]);

            return $correction;
        });

        return response()->json([
            'message'    => 'Paiement corrigé avec succès',
            'paiement'   => $paiement->fresh(['eleve', 'fraisScolaire', 'echeance']),
            'correction' => $correction,
        ], 201);
    }

    // GET /paiements/corrections/{paiementId}/historique
    public function historique($paiementId)
    {
        $corrections = CorrectionPaiement::where('paiement_id', $paiementId)
            ->with('corrigePar')
            ->orderByDesc('created_at')
            ->get();

        return response()->json($corrections);
    }
}
