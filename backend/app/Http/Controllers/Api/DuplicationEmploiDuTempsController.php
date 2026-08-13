<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Models\EmploiDuTemps;
use App\Models\HistoriqueEmploiDuTemps;
use App\Models\Seance;
use App\Services\ConflitEmploiDuTempsService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DuplicationEmploiDuTempsController extends Controller
{
    public function __construct(private ConflitEmploiDuTempsService $conflits)
    {
    }

    // POST /emploi-du-temps/duplication
    public function dupliquer(Request $request)
    {
        $data = $request->validate([
            'emploi_du_temps_source_id' => 'required|integer',
            'classe_destination_id' => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $source = EmploiDuTemps::where('id', $data['emploi_du_temps_source_id'])
            ->where('ecole_id', $ecoleId)
            ->with(['seances', 'classe:id,nom'])
            ->firstOrFail();

        $classeDestination = Classe::where('id', $data['classe_destination_id'])
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        if ($classeDestination->id === $source->classe_id) {
            return response()->json([
                'message' => 'La classe de destination doit être différente de la classe source.',
            ], 422);
        }

        $existant = EmploiDuTemps::where('classe_id', $classeDestination->id)
            ->where('periode_id', $source->periode_id)
            ->first();
        if ($existant) {
            return response()->json([
                'message' => 'Un emploi du temps existe déjà pour la classe de destination sur cette période.',
                'emploi_du_temps' => $existant,
            ], 409);
        }

        $seancesCopiees = [];
        $seancesEnConflit = [];

        $nouvelEmploiDuTemps = DB::transaction(function () use (
            $source,
            $classeDestination,
            $ecoleId,
            $request,
            &$seancesCopiees,
            &$seancesEnConflit
        ) {
            $nouveau = EmploiDuTemps::create([
                'ecole_id' => $ecoleId,
                'classe_id' => $classeDestination->id,
                'annee_scolaire_id' => $source->annee_scolaire_id,
                'periode_id' => $source->periode_id,
                'statut' => 'brouillon',
                'cree_par' => $request->user()->id,
            ]);

            foreach ($source->seances as $seanceSource) {
                $conflitEnseignant = $this->conflits->verifierConflitEnseignant(
                    $seanceSource->enseignant_id,
                    $seanceSource->jour,
                    $seanceSource->creneau_horaire_id,
                    $nouveau->id
                );

                if ($conflitEnseignant) {
                    $seancesEnConflit[] = [
                        'jour' => $seanceSource->jour,
                        'creneau_horaire_id' => $seanceSource->creneau_horaire_id,
                        'matiere_id' => $seanceSource->matiere_id,
                        'enseignant_id' => $seanceSource->enseignant_id,
                        'conflit' => $conflitEnseignant,
                    ];
                    continue;
                }

                $seancesCopiees[] = Seance::create([
                    'ecole_id' => $ecoleId,
                    'emploi_du_temps_id' => $nouveau->id,
                    'creneau_horaire_id' => $seanceSource->creneau_horaire_id,
                    'jour' => $seanceSource->jour,
                    'matiere_id' => $seanceSource->matiere_id,
                    'enseignant_id' => $seanceSource->enseignant_id,
                    'salle' => $seanceSource->salle,
                    'couleur' => $seanceSource->couleur,
                ]);
            }

            HistoriqueEmploiDuTemps::create([
                'emploi_du_temps_id' => $nouveau->id,
                'action' => 'duplication',
                'effectue_par' => $request->user()->id,
                'details' => "Dupliqué depuis l'emploi du temps #{$source->id} ({$source->classe->nom})."
                    . (count($seancesEnConflit) > 0
                        ? ' ' . count($seancesEnConflit) . " séance(s) non copiée(s) pour cause de conflit."
                        : ''),
            ]);

            return $nouveau;
        });

        return response()->json([
            'message' => count($seancesCopiees) . ' séance(s) copiée(s), '
                . count($seancesEnConflit) . ' en conflit (non copiée(s)).',
            'emploi_du_temps' => $nouvelEmploiDuTemps->load(['classe:id,nom', 'periode:id,nom']),
            'seances_copiees' => $seancesCopiees,
            'seances_en_conflit' => $seancesEnConflit,
        ], count($seancesEnConflit) > 0 ? 207 : 201);
    }
}
