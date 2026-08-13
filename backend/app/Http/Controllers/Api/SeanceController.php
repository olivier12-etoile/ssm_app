<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\EmploiDuTemps;
use App\Models\HistoriqueEmploiDuTemps;
use App\Models\Seance;
use App\Services\ConflitEmploiDuTempsService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SeanceController extends Controller
{
    public function __construct(private ConflitEmploiDuTempsService $conflits)
    {
    }

    // POST /emploi-du-temps/seances
    public function store(Request $request)
    {
        $data = $request->validate([
            'emploi_du_temps_id' => 'required|integer',
            'creneau_horaire_id' => 'required|integer',
            'jour' => 'required|in:lundi,mardi,mercredi,jeudi,vendredi,samedi',
            'matiere_id' => 'required|integer',
            'enseignant_id' => 'required|integer',
            'salle' => 'nullable|string|max:100',
            'couleur' => 'nullable|string|max:7',
        ]);

        $ecoleId = $request->user()->ecole_id;
        $emploiDuTemps = EmploiDuTemps::where('id', $data['emploi_du_temps_id'])
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        if ($emploiDuTemps->statut === 'valide') {
            return response()->json([
                'message' => 'Cet emploi du temps est validé et ne peut plus être modifié.',
            ], 403);
        }

        $conflits = $this->conflits->verifierTous($data);
        if (!empty($conflits)) {
            return response()->json([
                'message' => "Impossible d'enregistrer la séance : des conflits ont été détectés.",
                'conflits' => $conflits,
            ], 422);
        }

        $seance = DB::transaction(function () use ($data, $ecoleId, $request) {
            $seance = Seance::create([
                'ecole_id' => $ecoleId,
                'emploi_du_temps_id' => $data['emploi_du_temps_id'],
                'creneau_horaire_id' => $data['creneau_horaire_id'],
                'jour' => $data['jour'],
                'matiere_id' => $data['matiere_id'],
                'enseignant_id' => $data['enseignant_id'],
                'salle' => $data['salle'] ?? null,
                'couleur' => $data['couleur'] ?? null,
            ]);

            HistoriqueEmploiDuTemps::create([
                'emploi_du_temps_id' => $data['emploi_du_temps_id'],
                'action' => 'modification',
                'effectue_par' => $request->user()->id,
                'details' => "Séance ajoutée ({$data['jour']}).",
            ]);

            return $seance;
        });

        return response()->json([
            'message' => 'Séance enregistrée avec succès',
            'seance' => $seance->load(['creneauHoraire', 'matiere:id,nom', 'enseignant:id,name']),
        ], 201);
    }

    // PUT /emploi-du-temps/seances/{id}
    public function update(Request $request, $id)
    {
        $seance = Seance::with('emploiDuTemps')->findOrFail($id);

        if ($seance->emploiDuTemps->statut === 'valide') {
            return response()->json([
                'message' => 'Cet emploi du temps est validé et ne peut plus être modifié.',
            ], 403);
        }

        $data = $request->validate([
            'creneau_horaire_id' => 'sometimes|required|integer',
            'jour' => 'sometimes|required|in:lundi,mardi,mercredi,jeudi,vendredi,samedi',
            'matiere_id' => 'sometimes|required|integer',
            'enseignant_id' => 'sometimes|required|integer',
            'salle' => 'nullable|string|max:100',
            'couleur' => 'nullable|string|max:7',
        ]);

        $donneesVerif = array_merge([
            'emploi_du_temps_id' => $seance->emploi_du_temps_id,
            'creneau_horaire_id' => $seance->creneau_horaire_id,
            'jour' => $seance->jour,
            'matiere_id' => $seance->matiere_id,
            'enseignant_id' => $seance->enseignant_id,
            'salle' => $seance->salle,
        ], $data, ['seance_id_exclu' => $seance->id]);

        $conflits = $this->conflits->verifierTous($donneesVerif);
        if (!empty($conflits)) {
            return response()->json([
                'message' => 'Impossible de modifier la séance : des conflits ont été détectés.',
                'conflits' => $conflits,
            ], 422);
        }

        $seance->update($data);

        HistoriqueEmploiDuTemps::create([
            'emploi_du_temps_id' => $seance->emploi_du_temps_id,
            'action' => 'modification',
            'effectue_par' => $request->user()->id,
            'details' => "Séance #{$seance->id} modifiée.",
        ]);

        return response()->json([
            'message' => 'Séance modifiée avec succès',
            'seance' => $seance->fresh()->load(['creneauHoraire', 'matiere:id,nom', 'enseignant:id,name']),
        ]);
    }

    // DELETE /emploi-du-temps/seances/{id}
    public function destroy(Request $request, $id)
    {
        $seance = Seance::with('emploiDuTemps')->findOrFail($id);

        if ($seance->emploiDuTemps->statut === 'valide') {
            return response()->json([
                'message' => 'Cet emploi du temps est validé et ne peut plus être modifié.',
            ], 403);
        }

        $emploiDuTempsId = $seance->emploi_du_temps_id;
        $seance->delete();

        HistoriqueEmploiDuTemps::create([
            'emploi_du_temps_id' => $emploiDuTempsId,
            'action' => 'modification',
            'effectue_par' => $request->user()->id,
            'details' => 'Séance supprimée.',
        ]);

        return response()->json(['message' => 'Séance supprimée avec succès']);
    }

    // POST /emploi-du-temps/seances/bulk
    public function storeBulk(Request $request)
    {
        $data = $request->validate([
            'emploi_du_temps_id' => 'required|integer',
            'seances' => 'required|array|min:1',
            'seances.*.creneau_horaire_id' => 'required|integer',
            'seances.*.jour' => 'required|in:lundi,mardi,mercredi,jeudi,vendredi,samedi',
            'seances.*.matiere_id' => 'required|integer',
            'seances.*.enseignant_id' => 'required|integer',
            'seances.*.salle' => 'nullable|string|max:100',
            'seances.*.couleur' => 'nullable|string|max:7',
        ]);

        $ecoleId = $request->user()->ecole_id;
        $emploiDuTemps = EmploiDuTemps::where('id', $data['emploi_du_temps_id'])
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        if ($emploiDuTemps->statut === 'valide') {
            return response()->json([
                'message' => 'Cet emploi du temps est validé et ne peut plus être modifié.',
            ], 403);
        }

        $reussies = [];
        $echouees = [];

        foreach ($data['seances'] as $index => $ligne) {
            $donneesVerif = array_merge($ligne, ['emploi_du_temps_id' => $emploiDuTemps->id]);
            $conflits = $this->conflits->verifierTous($donneesVerif);

            if (!empty($conflits)) {
                $echouees[] = ['index' => $index, 'donnees' => $ligne, 'conflits' => $conflits];
                continue;
            }

            $seance = Seance::create([
                'ecole_id' => $ecoleId,
                'emploi_du_temps_id' => $emploiDuTemps->id,
                'creneau_horaire_id' => $ligne['creneau_horaire_id'],
                'jour' => $ligne['jour'],
                'matiere_id' => $ligne['matiere_id'],
                'enseignant_id' => $ligne['enseignant_id'],
                'salle' => $ligne['salle'] ?? null,
                'couleur' => $ligne['couleur'] ?? null,
            ]);

            $reussies[] = $seance;
        }

        if (!empty($reussies)) {
            HistoriqueEmploiDuTemps::create([
                'emploi_du_temps_id' => $emploiDuTemps->id,
                'action' => 'modification',
                'effectue_par' => $request->user()->id,
                'details' => count($reussies) . ' séance(s) ajoutée(s) en masse.',
            ]);
        }

        return response()->json([
            'message' => count($reussies) . ' séance(s) enregistrée(s), ' . count($echouees) . ' échec(s).',
            'reussies' => $reussies,
            'echouees' => $echouees,
        ], count($echouees) > 0 ? 207 : 201);
    }
}
