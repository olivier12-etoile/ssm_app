<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\RemplacementSeance;
use App\Models\Seance;
use App\Services\ConflitEmploiDuTempsService;
use Illuminate\Http\Request;

class RemplacementController extends Controller
{
    public function __construct(private ConflitEmploiDuTempsService $conflits)
    {
    }

    // POST /emploi-du-temps/remplacements
    public function store(Request $request)
    {
        $data = $request->validate([
            'seance_id' => 'required|integer',
            'date_remplacement' => 'required|date',
            'enseignant_remplacant_id' => 'required|integer',
            'motif' => 'nullable|string',
        ]);

        // Seance porte déjà le filtre global par école (FiltreParEcole).
        $seance = Seance::with('emploiDuTemps')->findOrFail($data['seance_id']);

        if ($data['enseignant_remplacant_id'] === $seance->enseignant_id) {
            return response()->json([
                'message' => "L'enseignant remplaçant doit être différent de l'enseignant titulaire de la séance.",
            ], 422);
        }

        $conflit = $this->conflits->verifierConflitEnseignant(
            $data['enseignant_remplacant_id'],
            $seance->jour,
            $seance->creneau_horaire_id,
            $seance->emploi_du_temps_id
        );

        if ($conflit) {
            return response()->json([
                'message' => "Impossible d'enregistrer le remplacement : l'enseignant remplaçant a déjà cours sur ce créneau.",
                'conflit' => $conflit,
            ], 422);
        }

        $remplacement = RemplacementSeance::create([
            'seance_id' => $seance->id,
            'date_remplacement' => $data['date_remplacement'],
            'enseignant_remplacant_id' => $data['enseignant_remplacant_id'],
            'motif' => $data['motif'] ?? null,
            'enregistre_par' => $request->user()->id,
        ]);

        return response()->json([
            'message' => 'Remplacement enregistré avec succès',
            'remplacement' => $remplacement->load([
                'seance.creneauHoraire',
                'seance.matiere:id,nom',
                'seance.enseignant:id,name',
                'seance.emploiDuTemps.classe:id,nom',
                'enseignantRemplacant:id,name',
            ]),
        ], 201);
    }

    // GET /emploi-du-temps/remplacements
    public function index(Request $request)
    {
        $remplacements = RemplacementSeance::whereHas('seance')
            ->with([
                'seance.creneauHoraire',
                'seance.matiere:id,nom',
                'seance.enseignant:id,name',
                'seance.emploiDuTemps.classe:id,nom',
                'enseignantRemplacant:id,name',
            ])
            ->when($request->filled('date'), fn ($q) => $q->where('date_remplacement', $request->date))
            ->when($request->filled('enseignant_id'), function ($q) use ($request) {
                $q->where(function ($q2) use ($request) {
                    $q2->where('enseignant_remplacant_id', $request->enseignant_id)
                        ->orWhereHas('seance', fn ($q3) => $q3->where('enseignant_id', $request->enseignant_id));
                });
            })
            ->when($request->filled('classe_id'), function ($q) use ($request) {
                $q->whereHas('seance.emploiDuTemps', fn ($q2) => $q2->where('classe_id', $request->classe_id));
            })
            ->orderByDesc('date_remplacement')
            ->get();

        return response()->json(['remplacements' => $remplacements]);
    }

    // DELETE /emploi-du-temps/remplacements/{id}
    public function destroy($id)
    {
        $remplacement = RemplacementSeance::whereHas('seance')->findOrFail($id);
        $remplacement->delete();

        return response()->json(['message' => 'Remplacement annulé avec succès']);
    }
}
