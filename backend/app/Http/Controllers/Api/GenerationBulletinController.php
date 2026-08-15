<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Services\GenerationBulletinService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use RuntimeException;

class GenerationBulletinController extends Controller
{
    public function __construct(private GenerationBulletinService $service)
    {
    }

    // POST /bulletins/generation/individuel
    public function genererIndividuel(Request $request)
    {
        $data = $request->validate([
            'eleve_id' => ['required', 'integer', Rule::exists('eleves', 'id')->where('ecole_id', $request->user()->ecole_id)],
            'periode_id' => ['required', 'integer', 'exists:periodes_academiques,id'],
        ]);

        try {
            $bulletin = $this->service->genererPourEleve($data['eleve_id'], $data['periode_id']);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json([
            'message' => 'Bulletin généré avec succès',
            'bulletin' => $bulletin,
        ], 201);
    }

    // POST /bulletins/generation/classe
    public function genererClasse(Request $request)
    {
        $data = $request->validate([
            'classe_id' => ['required', 'integer', Rule::exists('classes', 'id')->where('ecole_id', $request->user()->ecole_id)],
            'periode_id' => ['required', 'integer', 'exists:periodes_academiques,id'],
        ]);

        $resume = $this->service->genererPourClasse($data['classe_id'], $data['periode_id']);

        return response()->json([
            'message' => "{$resume['nombre_reussis']} bulletin(s) généré(s), {$resume['nombre_echecs']} échec(s).",
            'resume' => $resume,
        ]);
    }

    // POST /bulletins/generation/regenerer
    public function regenererIndividuel(Request $request)
    {
        $data = $request->validate([
            'eleve_id' => ['required', 'integer', Rule::exists('eleves', 'id')->where('ecole_id', $request->user()->ecole_id)],
            'periode_id' => ['required', 'integer', 'exists:periodes_academiques,id'],
        ]);

        try {
            $bulletin = $this->service->regenererPourEleve($data['eleve_id'], $data['periode_id']);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json([
            'message' => 'Bulletin régénéré avec succès',
            'bulletin' => $bulletin,
        ]);
    }

    // GET /bulletins/generation/statut/{classeId}/{periodeId}
    public function statutGeneration(Request $request, int $classeId, int $periodeId)
    {
        $classe = Classe::where('id', $classeId)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        return response()->json([
            'classe_id' => $classe->id,
            'periode_id' => $periodeId,
            'eleves' => $this->service->statutGeneration($classeId, $periodeId),
        ]);
    }
}
