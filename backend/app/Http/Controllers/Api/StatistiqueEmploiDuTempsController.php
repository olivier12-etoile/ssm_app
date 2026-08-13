<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ClasseMatiere;
use App\Models\EmploiDuTemps;
use App\Models\PeriodeAcademique;
use App\Models\Seance;
use Illuminate\Http\Request;

class StatistiqueEmploiDuTempsController extends Controller
{
    // GET /emploi-du-temps/statistiques/heures-enseignant?periode_id=
    public function heuresParEnseignant(Request $request)
    {
        $periode = $this->periodeEcole($request);

        $seances = $this->seancesDeCoursDeLaPeriode($periode->id, ['enseignant:id,name']);

        $resultat = $seances
            ->groupBy('enseignant_id')
            ->map(function ($seancesEnseignant) {
                $enseignant = $seancesEnseignant->first()->enseignant;

                return [
                    'enseignant_id' => $enseignant?->id,
                    'enseignant_nom' => $enseignant?->name,
                    'nombre_seances' => $seancesEnseignant->count(),
                    'heures' => $this->totalHeures($seancesEnseignant),
                ];
            })
            ->sortByDesc('heures')
            ->values();

        return response()->json(['heures_par_enseignant' => $resultat]);
    }

    // GET /emploi-du-temps/statistiques/heures-matiere?periode_id=
    public function heuresParMatiere(Request $request)
    {
        $periode = $this->periodeEcole($request);

        $seances = $this->seancesDeCoursDeLaPeriode($periode->id, ['matiere:id,nom']);

        $resultat = $seances
            ->groupBy('matiere_id')
            ->map(function ($seancesMatiere) {
                $matiere = $seancesMatiere->first()->matiere;

                return [
                    'matiere_id' => $matiere?->id,
                    'matiere_nom' => $matiere?->nom,
                    'nombre_seances' => $seancesMatiere->count(),
                    'heures' => $this->totalHeures($seancesMatiere),
                ];
            })
            ->sortByDesc('heures')
            ->values();

        return response()->json(['heures_par_matiere' => $resultat]);
    }

    // GET /emploi-du-temps/statistiques/heures-classe?periode_id=
    public function heuresParClasse(Request $request)
    {
        $periode = $this->periodeEcole($request);

        $seances = $this->seancesDeCoursDeLaPeriode($periode->id, ['emploiDuTemps.classe:id,nom']);

        $resultat = $seances
            ->groupBy(fn (Seance $s) => $s->emploiDuTemps->classe_id)
            ->map(function ($seancesClasse) {
                $classe = $seancesClasse->first()->emploiDuTemps->classe;

                return [
                    'classe_id' => $classe?->id,
                    'classe_nom' => $classe?->nom,
                    'nombre_seances' => $seancesClasse->count(),
                    'heures' => $this->totalHeures($seancesClasse),
                ];
            })
            ->sortBy('classe_nom')
            ->values();

        return response()->json(['heures_par_classe' => $resultat]);
    }

    // GET /emploi-du-temps/statistiques/taux-completion?periode_id=
    public function tauxCompletionGlobal(Request $request)
    {
        $periode = $this->periodeEcole($request);

        $emplois = EmploiDuTemps::where('periode_id', $periode->id)->get();

        $details = $emplois->map(function (EmploiDuTemps $emploi) {
            $volumesAttendus = ClasseMatiere::where('classe_id', $emploi->classe_id)->get();
            $volumesProgrammes = $emploi->volumeHoraireParMatiere->keyBy('matiere_id');

            $totalAttendu = (float) $volumesAttendus->sum('volume_horaire_hebdomadaire');

            if ($totalAttendu <= 0) {
                return null;
            }

            $totalProgramme = $volumesAttendus->sum(function (ClasseMatiere $cm) use ($volumesProgrammes) {
                $programme = $volumesProgrammes->get($cm->matiere_id)?->volume_horaire ?? 0;

                // On ne compte pas le surplus programmé au-delà de l'attendu.
                return min($programme, (float) $cm->volume_horaire_hebdomadaire);
            });

            return [
                'classe_id' => $emploi->classe_id,
                'classe_nom' => $emploi->classe?->nom,
                'pourcentage' => (int) round(($totalProgramme / $totalAttendu) * 100),
            ];
        })->filter()->values();

        $tauxMoyen = $details->isNotEmpty() ? (int) round($details->avg('pourcentage')) : 0;

        return response()->json([
            'taux_completion_moyen' => $tauxMoyen,
            'details_par_classe' => $details,
        ]);
    }

    // ── Aides internes ────────────────────────────────────────────

    private function periodeEcole(Request $request): PeriodeAcademique
    {
        $ecoleId = $request->user()->ecole_id;

        return PeriodeAcademique::whereHas('annee', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->findOrFail($request->integer('periode_id'));
    }

    // Séances de type "cours" (récréations/pauses exclues) de la période, avec les relations demandées.
    private function seancesDeCoursDeLaPeriode(int $periodeId, array $with = [])
    {
        return Seance::whereHas('emploiDuTemps', fn ($q) => $q->where('periode_id', $periodeId))
            ->with(array_merge(['creneauHoraire'], $with))
            ->get()
            ->filter(fn (Seance $s) => $s->creneauHoraire?->type === 'cours');
    }

    private function totalHeures($seances): float
    {
        $minutes = $seances->sum(function (Seance $s) {
            $debut = $s->creneauHoraire->heure_debut;
            $fin = $s->creneauHoraire->heure_fin;

            return $fin->diffInMinutes($debut, true);
        });

        return round($minutes / 60, 2);
    }
}
