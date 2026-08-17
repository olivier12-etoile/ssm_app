<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppelPresence;
use App\Services\PresenceService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use RuntimeException;

class PresenceController extends Controller
{
    public function __construct(private PresenceService $service)
    {
    }

    public function creerAppel(Request $request)
    {
        $data = $request->validate([
            'classe_id' => ['required', 'integer', Rule::exists('classes', 'id')->where('ecole_id', $request->user()->ecole_id)],
            'matiere_id' => ['nullable', 'integer', Rule::exists('matieres', 'id')->where('ecole_id', $request->user()->ecole_id)],
            'periode_id' => ['required', 'integer', 'exists:periodes_academiques,id'],
            'date_appel' => ['required', 'date'],
            'creneau_horaire_id' => ['nullable', 'integer', 'exists:creneaux_horaires,id'],
        ]);

        try {
            $appel = $this->service->creerAppel(
                $data['classe_id'],
                $data['matiere_id'] ?? null,
                $data['periode_id'],
                $data['date_appel'],
                $data['creneau_horaire_id'] ?? null
            );
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json(['message' => 'Appel créé avec succès', 'appel' => $appel], 201);
    }

    public function getAppel(Request $request, int $appelId)
    {
        $appel = AppelPresence::with(['presences.eleve', 'classe', 'matiere', 'creneauHoraire'])
            ->where('id', $appelId)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        return response()->json($appel);
    }

    public function marquerPresence(Request $request, int $appelId)
    {
        $data = $request->validate([
            'eleve_id' => ['required', 'integer', Rule::exists('eleves', 'id')->where('ecole_id', $request->user()->ecole_id)],
            'statut' => ['required', Rule::in(['present', 'absent', 'retard'])],
            'justifie' => ['nullable', 'boolean'],
            'motif' => ['nullable', 'string'],
            'minutes_retard' => ['nullable', 'integer', 'min:0'],
        ]);

        try {
            $presence = $this->service->marquerPresence(
                $appelId,
                $data['eleve_id'],
                $data['statut'],
                $data['justifie'] ?? false,
                $data['motif'] ?? null,
                $data['minutes_retard'] ?? null
            );
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json(['message' => 'Présence mise à jour', 'presence' => $presence]);
    }

    public function marquerPresenceBulk(Request $request, int $appelId)
    {
        $data = $request->validate([
            'statuts' => ['required', 'array', 'min:1'],
            'statuts.*.eleve_id' => ['required', 'integer'],
            'statuts.*.statut' => ['required', Rule::in(['present', 'absent', 'retard'])],
            'statuts.*.justifie' => ['nullable', 'boolean'],
            'statuts.*.motif_justification' => ['nullable', 'string'],
            'statuts.*.minutes_retard' => ['nullable', 'integer', 'min:0'],
        ]);

        try {
            $appel = $this->service->marquerPresenceBulk($appelId, $data['statuts']);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json(['message' => 'Présences mises à jour', 'appel' => $appel]);
    }

    public function terminerAppel(int $appelId)
    {
        try {
            $appel = $this->service->terminerAppel($appelId);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json(['message' => 'Appel terminé, parents notifiés', 'appel' => $appel]);
    }

    public function historiqueEleve(int $eleveId, int $periodeId)
    {
        return response()->json($this->service->historiqueEleve($eleveId, $periodeId));
    }

    public function statistiquesClasse(int $classeId, int $periodeId)
    {
        return response()->json($this->service->statistiquesClasse($classeId, $periodeId));
    }

    public function appelsRecents(int $classeId)
    {
        return response()->json($this->service->appelsRecents($classeId));
    }
}
