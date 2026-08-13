<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Models\ClasseMatiere;
use App\Models\EmploiDuTemps;
use App\Models\PeriodeAcademique;
use App\Models\Seance;
use App\Services\ConflitEmploiDuTempsService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class DashboardEmploiDuTempsController extends Controller
{
    // Ordre des jours de la grille ; "dimanche" n'existe pas dans l'enum jour des séances.
    private const JOURS_SEMAINE = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];

    public function __construct(private ConflitEmploiDuTempsService $conflits)
    {
    }

    // GET /emploi-du-temps/dashboard/resume?periode_id=
    public function resume(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->findOrFail($request->integer('periode_id'));

        $emplois = EmploiDuTemps::where('periode_id', $periode->id)
            ->with('seances.creneauHoraire')
            ->get();

        return response()->json([
            'nombre_classes' => Classe::where('ecole_id', $ecoleId)->count(),
            'nombre_emplois_crees' => $emplois->count(),
            'nombre_emplois_valides' => $emplois->where('statut', 'valide')->count(),
            'nombre_conflits' => $this->compterConflits($emplois),
            'nombre_seances_aujourdhui' => $this->compterSeancesAujourdhui($periode->id),
            'nombre_emplois_incomplets' => $this->compterEmploisIncomplets($emplois),
        ]);
    }

    // Reparcourt toutes les séances actives de la période et recompte les
    // conflits avec le même service que la validation, pour refléter l'état
    // réel (des changements de créneaux/enseignants ailleurs peuvent avoir
    // fait apparaître des conflits après coup).
    private function compterConflits($emplois): int
    {
        $nombreSeancesEnConflit = 0;

        foreach ($emplois as $emploi) {
            foreach ($emploi->seances as $seance) {
                $conflitsSeance = $this->conflits->verifierTous([
                    'emploi_du_temps_id' => $emploi->id,
                    'creneau_horaire_id' => $seance->creneau_horaire_id,
                    'jour' => $seance->jour,
                    'matiere_id' => $seance->matiere_id,
                    'enseignant_id' => $seance->enseignant_id,
                    'salle' => $seance->salle,
                    'seance_id_exclu' => $seance->id,
                ]);

                if (!empty($conflitsSeance)) {
                    $nombreSeancesEnConflit++;
                }
            }
        }

        return $nombreSeancesEnConflit;
    }

    private function compterSeancesAujourdhui(int $periodeId): int
    {
        $indexJour = Carbon::now()->dayOfWeekIso; // 1 = lundi ... 7 = dimanche

        if (!isset(self::JOURS_SEMAINE[$indexJour - 1])) {
            return 0; // dimanche : pas de jour correspondant dans l'enum
        }

        $jourAujourdhui = self::JOURS_SEMAINE[$indexJour - 1];

        return Seance::where('jour', $jourAujourdhui)
            ->whereHas('emploiDuTemps', fn ($q) => $q->where('periode_id', $periodeId))
            ->count();
    }

    // Un emploi du temps est incomplet si au moins une matière attendue pour
    // la classe (classe_matiere) n'atteint pas son volume horaire hebdomadaire.
    private function compterEmploisIncomplets($emplois): int
    {
        $nombreIncomplets = 0;

        foreach ($emplois as $emploi) {
            $volumesAttendus = ClasseMatiere::where('classe_id', $emploi->classe_id)->get();

            if ($volumesAttendus->isEmpty()) {
                continue;
            }

            $volumesProgrammes = $emploi->volumeHoraireParMatiere->keyBy('matiere_id');

            foreach ($volumesAttendus as $attendu) {
                if (!$attendu->volume_horaire_hebdomadaire) {
                    continue;
                }

                $programme = $volumesProgrammes->get($attendu->matiere_id)?->volume_horaire ?? 0;

                if ($programme < $attendu->volume_horaire_hebdomadaire) {
                    $nombreIncomplets++;
                    break;
                }
            }
        }

        return $nombreIncomplets;
    }
}
