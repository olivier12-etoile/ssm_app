<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CreneauHoraire;
use App\Models\JourTravaille;
use App\Models\PeriodeAcademique;
use App\Models\Seance;
use App\Models\User;
use Illuminate\Http\Request;

class DisponibiliteEnseignantController extends Controller
{
    // GET /emploi-du-temps/disponibilite/{enseignantId}?periode_id=
    public function index(Request $request, $enseignantId)
    {
        $ecoleId = $request->user()->ecole_id;

        $enseignant = User::where('id', $enseignantId)
            ->where('ecole_id', $ecoleId)
            ->where('role', 'enseignant')
            ->firstOrFail();

        $periode = PeriodeAcademique::whereHas('annee', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->findOrFail($request->integer('periode_id'));

        [$creneaux, $jours] = $this->grilleReference($periode->annee_academique_id);

        $seances = Seance::where('enseignant_id', $enseignant->id)
            ->whereHas('emploiDuTemps', fn ($q) => $q->where('periode_id', $periode->id))
            ->with(['emploiDuTemps.classe:id,nom', 'matiere:id,nom'])
            ->get()
            ->groupBy(fn (Seance $s) => $s->jour . '-' . $s->creneau_horaire_id);

        $grille = $jours->mapWithKeys(function (JourTravaille $jourTravaille) use ($creneaux, $seances) {
            $creneauxDuJour = $creneaux->map(function (CreneauHoraire $creneau) use ($jourTravaille, $seances) {
                $seance = $seances->get($jourTravaille->jour . '-' . $creneau->id)?->first();

                return [
                    'creneau_horaire_id' => $creneau->id,
                    'creneau_libelle' => $creneau->libelle,
                    'statut' => $seance ? 'occupe' : 'libre',
                    'classe_nom' => $seance?->emploiDuTemps->classe->nom,
                    'matiere_nom' => $seance?->matiere->nom,
                ];
            });

            return [$jourTravaille->jour => $creneauxDuJour->values()];
        });

        return response()->json([
            'enseignant' => $enseignant->only(['id', 'name']),
            'disponibilite' => $grille,
        ]);
    }

    // GET /emploi-du-temps/disponibilite/creneau?periode_id=&jour=&creneau_horaire_id=
    public function tousLesEnseignants(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $data = $request->validate([
            'periode_id' => 'required|integer',
            'jour' => 'required|in:lundi,mardi,mercredi,jeudi,vendredi,samedi',
            'creneau_horaire_id' => 'required|integer',
        ]);

        $periode = PeriodeAcademique::whereHas('annee', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->findOrFail($data['periode_id']);

        $enseignants = User::where('ecole_id', $ecoleId)
            ->where('role', 'enseignant')
            ->orderBy('name')
            ->get(['id', 'name']);

        $seancesDuCreneau = Seance::where('jour', $data['jour'])
            ->where('creneau_horaire_id', $data['creneau_horaire_id'])
            ->whereHas('emploiDuTemps', fn ($q) => $q->where('periode_id', $periode->id))
            ->with(['emploiDuTemps.classe:id,nom', 'matiere:id,nom'])
            ->get()
            ->keyBy('enseignant_id');

        $resultat = $enseignants->map(function (User $enseignant) use ($seancesDuCreneau) {
            $seance = $seancesDuCreneau->get($enseignant->id);

            return [
                'enseignant_id' => $enseignant->id,
                'enseignant_nom' => $enseignant->name,
                'statut' => $seance ? 'occupe' : 'libre',
                'classe_nom' => $seance?->emploiDuTemps->classe->nom,
                'matiere_nom' => $seance?->matiere->nom,
            ];
        });

        return response()->json(['enseignants' => $resultat->values()]);
    }

    // Créneaux de cours et jours travaillés actifs de référence pour l'année scolaire.
    private function grilleReference(int $anneeScolaireId): array
    {
        $creneaux = CreneauHoraire::where('annee_scolaire_id', $anneeScolaireId)
            ->where('type', 'cours')
            ->orderBy('ordre')
            ->get();

        $jours = JourTravaille::where('annee_scolaire_id', $anneeScolaireId)
            ->where('actif', true)
            ->get();

        return [$creneaux, $jours];
    }
}
