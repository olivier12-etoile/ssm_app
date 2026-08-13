<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Models\CreneauHoraire;
use App\Models\EmploiDuTemps;
use App\Models\JourTravaille;
use App\Models\PeriodeAcademique;
use App\Models\Seance;
use Illuminate\Http\Request;

class ConsultationEmploiDuTempsController extends Controller
{
    // GET /emploi-du-temps/consultation/classe/{classeId}?periode_id=
    public function parClasse(Request $request, $classeId)
    {
        $ecoleId = $request->user()->ecole_id;
        $periodeId = $request->integer('periode_id');

        $classe = Classe::where('id', $classeId)->where('ecole_id', $ecoleId)->firstOrFail();

        $emploiDuTemps = EmploiDuTemps::with(['periode:id,nom', 'anneeScolaire:id,libelle'])
            ->where('classe_id', $classe->id)
            ->when($periodeId, fn ($q) => $q->where('periode_id', $periodeId))
            ->first();

        if (!$emploiDuTemps) {
            return response()->json([
                'message' => "Aucun emploi du temps n'a encore été créé pour cette classe sur cette période.",
                'classe' => $classe,
                'emploi_du_temps' => null,
                'grille' => [],
                'seances' => [],
            ]);
        }

        $seances = $emploiDuTemps->seances()
            ->with(['creneauHoraire', 'matiere:id,nom', 'enseignant:id,name'])
            ->get();

        // Grille indexée par jour puis par créneau, prête pour l'affichage.
        $grille = $seances->groupBy('jour')->map(fn ($seancesJour) => $seancesJour->keyBy('creneau_horaire_id'));

        return response()->json([
            'classe' => $classe,
            'emploi_du_temps' => $emploiDuTemps,
            'grille' => $grille,
            'seances' => $seances,
        ]);
    }

    // GET /emploi-du-temps/consultation/mon-emploi-du-temps?periode_id=
    public function monEmploiDuTemps(Request $request)
    {
        $enseignantId = $request->user()->id;
        $periodeId = $request->integer('periode_id');

        $seances = Seance::where('enseignant_id', $enseignantId)
            ->whereHas('emploiDuTemps', function ($q) use ($periodeId) {
                if ($periodeId) {
                    $q->where('periode_id', $periodeId);
                }
            })
            ->with(['creneauHoraire', 'matiere:id,nom', 'emploiDuTemps.classe:id,nom'])
            ->get();

        // "Mon planning" : chaque séance porte la classe concernée, pour un
        // affichage direct sans avoir à re-router par emploi_du_temps.
        $grille = $seances
            ->groupBy('jour')
            ->map(fn ($seancesJour) => $seancesJour->keyBy('creneau_horaire_id')->map(fn (Seance $s) => [
                'seance_id' => $s->id,
                'creneau' => $s->creneauHoraire,
                'matiere' => $s->matiere,
                'salle' => $s->salle,
                'couleur' => $s->couleur,
                'classe' => $s->emploiDuTemps->classe,
            ]));

        return response()->json([
            'grille' => $grille,
            'seances' => $seances,
        ]);
    }

    // GET /emploi-du-temps/consultation/toutes-classes?periode_id=
    public function toutesLesClasses(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->findOrFail($request->integer('periode_id'));

        $anneeScolaireId = $periode->annee_academique_id;

        // Nombre de créneaux disponibles = créneaux de cours x jours travaillés
        // actifs pour l'année scolaire de la période demandée.
        $nombreCreneauxCours = CreneauHoraire::where('annee_scolaire_id', $anneeScolaireId)
            ->where('type', 'cours')
            ->count();

        $nombreJoursActifs = JourTravaille::where('annee_scolaire_id', $anneeScolaireId)
            ->where('actif', true)
            ->count();

        $totalCreneauxDisponibles = $nombreCreneauxCours * $nombreJoursActifs;

        $emploisParClasse = EmploiDuTemps::where('periode_id', $periode->id)
            ->withCount('seances')
            ->get()
            ->keyBy('classe_id');

        $classes = Classe::where('ecole_id', $ecoleId)->orderBy('nom')->get();

        $resultat = $classes->map(function (Classe $classe) use ($emploisParClasse, $totalCreneauxDisponibles) {
            $emploi = $emploisParClasse->get($classe->id);
            $nombreSeances = $emploi?->seances_count ?? 0;

            return [
                'classe_id' => $classe->id,
                'classe_nom' => $classe->nom,
                'emploi_du_temps_id' => $emploi?->id,
                'statut' => $emploi?->statut ?? 'non_cree',
                'nombre_seances' => $nombreSeances,
                'total_creneaux_disponibles' => $totalCreneauxDisponibles,
                'pourcentage_completion' => $totalCreneauxDisponibles > 0
                    ? (int) round(($nombreSeances / $totalCreneauxDisponibles) * 100)
                    : 0,
            ];
        });

        return response()->json(['classes' => $resultat]);
    }
}
