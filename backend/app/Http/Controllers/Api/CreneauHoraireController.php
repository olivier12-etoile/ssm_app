<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\CreneauHoraire;
use Illuminate\Http\Request;

class CreneauHoraireController extends Controller
{
    // GET /emploi-du-temps/creneaux-horaires
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $anneeId = $request->integer('annee_scolaire_id') ?: optional(
            AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->first()
        )->id;

        if (!$anneeId) {
            return response()->json(['message' => 'Aucune année scolaire active.'], 404);
        }

        $creneaux = CreneauHoraire::where('annee_scolaire_id', $anneeId)
            ->orderBy('ordre')
            ->get();

        return response()->json(['creneaux' => $creneaux]);
    }

    // POST /emploi-du-temps/creneaux-horaires
    public function store(Request $request)
    {
        $data = $request->validate([
            'libelle' => 'required|string|max:100',
            'heure_debut' => 'required|date_format:H:i',
            'heure_fin' => 'required|date_format:H:i|after:heure_debut',
            'ordre' => 'required|integer|min:1',
            'type' => 'required|in:cours,recreation,pause',
            'annee_scolaire_id' => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        AnneeAcademique::where('id', $data['annee_scolaire_id'])
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        if ($this->chevauche($ecoleId, $data['annee_scolaire_id'], $data['heure_debut'], $data['heure_fin'])) {
            return response()->json(['message' => 'Ce créneau chevauche un créneau existant.'], 422);
        }

        $creneau = CreneauHoraire::create([...$data, 'ecole_id' => $ecoleId]);

        return response()->json(['message' => 'Créneau créé avec succès', 'creneau' => $creneau], 201);
    }

    // PUT /emploi-du-temps/creneaux-horaires/{id}
    public function update(Request $request, $id)
    {
        $creneau = CreneauHoraire::findOrFail($id);

        $data = $request->validate([
            'libelle' => 'sometimes|required|string|max:100',
            'heure_debut' => 'sometimes|required|date_format:H:i',
            'heure_fin' => 'sometimes|required|date_format:H:i',
            'ordre' => 'sometimes|required|integer|min:1',
            'type' => 'sometimes|required|in:cours,recreation,pause',
        ]);

        $heureDebut = $data['heure_debut'] ?? $creneau->heure_debut->format('H:i');
        $heureFin = $data['heure_fin'] ?? $creneau->heure_fin->format('H:i');

        if ($heureFin <= $heureDebut) {
            return response()->json(['message' => "L'heure de fin doit être après l'heure de début."], 422);
        }

        if ($this->chevauche($creneau->ecole_id, $creneau->annee_scolaire_id, $heureDebut, $heureFin, $creneau->id)) {
            return response()->json(['message' => 'Ce créneau chevauche un créneau existant.'], 422);
        }

        $creneau->update($data);

        return response()->json(['message' => 'Créneau modifié avec succès', 'creneau' => $creneau->fresh()]);
    }

    // DELETE /emploi-du-temps/creneaux-horaires/{id}
    public function destroy($id)
    {
        $creneau = CreneauHoraire::findOrFail($id);

        if ($creneau->seances()->exists()) {
            return response()->json([
                'message' => 'Impossible de supprimer : des séances utilisent déjà ce créneau.',
            ], 422);
        }

        $creneau->delete();

        return response()->json(['message' => 'Créneau supprimé avec succès']);
    }

    private function chevauche(
        int $ecoleId,
        int $anneeScolaireId,
        string $heureDebut,
        string $heureFin,
        ?int $idExclu = null
    ): bool {
        return CreneauHoraire::where('ecole_id', $ecoleId)
            ->where('annee_scolaire_id', $anneeScolaireId)
            ->when($idExclu, fn ($q) => $q->where('id', '!=', $idExclu))
            ->where(function ($q) use ($heureDebut, $heureFin) {
                $q->where('heure_debut', '<', $heureFin)
                  ->where('heure_fin', '>', $heureDebut);
            })
            ->exists();
    }
}
