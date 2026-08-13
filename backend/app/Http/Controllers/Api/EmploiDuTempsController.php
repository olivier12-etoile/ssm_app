<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Models\EmploiDuTemps;
use App\Models\HistoriqueEmploiDuTemps;
use App\Models\PeriodeAcademique;
use App\Services\ConflitEmploiDuTempsService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class EmploiDuTempsController extends Controller
{
    public function __construct(private ConflitEmploiDuTempsService $conflits)
    {
    }

    // GET /emploi-du-temps/emplois-du-temps
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $emplois = EmploiDuTemps::where('ecole_id', $ecoleId)
            ->when($request->filled('classe_id'), fn ($q) => $q->where('classe_id', $request->classe_id))
            ->when($request->filled('statut'), fn ($q) => $q->where('statut', $request->statut))
            ->with(['classe:id,nom', 'periode:id,nom'])
            ->orderByDesc('created_at')
            ->get();

        return response()->json(['emplois_du_temps' => $emplois]);
    }

    // POST /emploi-du-temps/emplois-du-temps
    public function store(Request $request)
    {
        $data = $request->validate([
            'classe_id' => 'required|integer',
            'periode_id' => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $classe = Classe::where('id', $data['classe_id'])->where('ecole_id', $ecoleId)->firstOrFail();
        $periode = PeriodeAcademique::whereHas('annee', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->findOrFail($data['periode_id']);

        $existant = EmploiDuTemps::where('classe_id', $classe->id)->where('periode_id', $periode->id)->first();
        if ($existant) {
            return response()->json([
                'message' => 'Un emploi du temps existe déjà pour cette classe et cette période.',
                'emploi_du_temps' => $existant,
            ], 409);
        }

        $emploiDuTemps = DB::transaction(function () use ($ecoleId, $classe, $periode, $request) {
            $emploi = EmploiDuTemps::create([
                'ecole_id' => $ecoleId,
                'classe_id' => $classe->id,
                'annee_scolaire_id' => $periode->annee_academique_id,
                'periode_id' => $periode->id,
                'statut' => 'brouillon',
                'cree_par' => $request->user()->id,
            ]);

            HistoriqueEmploiDuTemps::create([
                'emploi_du_temps_id' => $emploi->id,
                'action' => 'creation',
                'effectue_par' => $request->user()->id,
            ]);

            return $emploi;
        });

        return response()->json([
            'message' => 'Emploi du temps créé avec succès',
            'emploi_du_temps' => $emploiDuTemps,
        ], 201);
    }

    // GET /emploi-du-temps/emplois-du-temps/{id}
    public function show($id)
    {
        $emploiDuTemps = EmploiDuTemps::with([
            'classe:id,nom',
            'periode:id,nom',
            'anneeScolaire:id,libelle',
            'creePar:id,name',
        ])->findOrFail($id);

        $seances = $emploiDuTemps->seances()
            ->with(['creneauHoraire', 'matiere:id,nom', 'enseignant:id,name'])
            ->get();

        // Grille indexée par jour puis par créneau, prête pour l'affichage.
        $grille = $seances->groupBy('jour')->map(fn ($seancesJour) => $seancesJour->keyBy('creneau_horaire_id'));

        return response()->json([
            'emploi_du_temps' => $emploiDuTemps,
            'grille' => $grille,
            'seances' => $seances,
            'volume_horaire_par_matiere' => $emploiDuTemps->volumeHoraireParMatiere,
        ]);
    }

    // POST /emploi-du-temps/emplois-du-temps/{id}/valider
    public function valider(Request $request, $id)
    {
        $emploiDuTemps = EmploiDuTemps::with('seances')->findOrFail($id);

        if ($emploiDuTemps->statut === 'valide') {
            return response()->json(['message' => 'Cet emploi du temps est déjà validé.'], 422);
        }

        $conflitsGlobaux = [];
        foreach ($emploiDuTemps->seances as $seance) {
            $conflits = $this->conflits->verifierTous([
                'emploi_du_temps_id' => $emploiDuTemps->id,
                'creneau_horaire_id' => $seance->creneau_horaire_id,
                'jour' => $seance->jour,
                'matiere_id' => $seance->matiere_id,
                'enseignant_id' => $seance->enseignant_id,
                'salle' => $seance->salle,
                'seance_id_exclu' => $seance->id,
            ]);

            if (!empty($conflits)) {
                $conflitsGlobaux[] = ['seance_id' => $seance->id, 'conflits' => $conflits];
            }
        }

        if (!empty($conflitsGlobaux)) {
            return response()->json([
                'message' => 'Impossible de valider : des conflits subsistent sur cet emploi du temps.',
                'conflits' => $conflitsGlobaux,
            ], 422);
        }

        DB::transaction(function () use ($emploiDuTemps, $request) {
            $emploiDuTemps->update(['statut' => 'valide']);

            HistoriqueEmploiDuTemps::create([
                'emploi_du_temps_id' => $emploiDuTemps->id,
                'action' => 'validation',
                'effectue_par' => $request->user()->id,
            ]);
        });

        return response()->json([
            'message' => 'Emploi du temps validé avec succès',
            'emploi_du_temps' => $emploiDuTemps->fresh(),
        ]);
    }

    // DELETE /emploi-du-temps/emplois-du-temps/{id}
    public function destroy($id)
    {
        $emploiDuTemps = EmploiDuTemps::findOrFail($id);

        if ($emploiDuTemps->statut !== 'brouillon') {
            return response()->json([
                'message' => 'Seul un emploi du temps en brouillon peut être supprimé.',
            ], 403);
        }

        $emploiDuTemps->delete();

        return response()->json(['message' => 'Emploi du temps supprimé avec succès']);
    }
}
