<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Models\Eleve;
use App\Models\Matiere;
use App\Models\Note;
use App\Models\PeriodeAcademique;
use App\Models\SaisieNote;
use Illuminate\Http\Request;

class SaisieNoteController extends Controller
{
    // POST /notes/saisie/demarrer
    // Crée (ou récupère si elle existe déjà) la session de saisie de
    // l'enseignant connecté pour une classe/matière/période donnée.
    public function demarrer(Request $request)
    {
        $data = $request->validate([
            'classe_id' => 'required|integer',
            'matiere_id' => 'required|integer',
            'periode_id' => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;
        $enseignantId = $request->user()->id;

        $classe = Classe::where('id', $data['classe_id'])->where('ecole_id', $ecoleId)->firstOrFail();
        $matiere = Matiere::where('id', $data['matiere_id'])->where('ecole_id', $ecoleId)->firstOrFail();
        $periode = PeriodeAcademique::whereHas('annee', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->where('id', $data['periode_id'])
            ->firstOrFail();

        $saisie = SaisieNote::where('enseignant_id', $enseignantId)
            ->where('classe_id', $classe->id)
            ->where('matiere_id', $matiere->id)
            ->where('periode_id', $periode->id)
            ->first();

        if (!$saisie) {
            $saisie = SaisieNote::create([
                'ecole_id' => $ecoleId,
                'enseignant_id' => $enseignantId,
                'classe_id' => $classe->id,
                'matiere_id' => $matiere->id,
                'periode_id' => $periode->id,
                'annee_scolaire_id' => $periode->annee_academique_id,
                'statut' => 'en_cours',
                'date_debut' => now()->toDateString(),
            ]);
        }

        return response()->json(['saisie' => $saisie->fresh(['classe', 'matiere', 'periode'])]);
    }

    // GET /notes/saisie/{id}/eleves
    // Liste des élèves de la classe avec leurs notes déjà saisies (le cas
    // échéant) pour la matière/période de cette saisie.
    public function eleves(Request $request, $id)
    {
        $saisie = SaisieNote::findOrFail($id);
        $this->autoriserAcces($request, $saisie);

        $eleves = Eleve::where('ecole_id', $saisie->ecole_id)
            ->whereHas('inscriptions', fn ($q) => $q
                ->where('classe_id', $saisie->classe_id)
                ->where('annee_academique_id', $saisie->annee_scolaire_id))
            ->orderBy('nom')
            ->get();

        $notesParEleve = $saisie->notes()->get()->groupBy('eleve_id');

        $resultat = $eleves->map(function (Eleve $eleve) use ($notesParEleve) {
            $notes = $notesParEleve->get($eleve->id, collect());

            return [
                'eleve_id' => $eleve->id,
                'nom' => $eleve->nom,
                'prenom' => $eleve->prenom,
                'matricule' => $eleve->matricule,
                'note_devoir' => $notes->firstWhere('type_evaluation', 'devoir'),
                'note_composition' => $notes->firstWhere('type_evaluation', 'composition'),
            ];
        });

        return response()->json([
            'saisie' => $saisie,
            'verrouillee' => $saisie->estVerrouillee(),
            'eleves' => $resultat,
        ]);
    }

    // GET /notes/saisie/progression
    // Pour l'enseignant connecté : ses saisies non finalisées (en_cours ou
    // rejetee), avec le pourcentage de notes déjà saisies (devoir +
    // composition attendus pour chaque élève de la classe).
    public function progression(Request $request)
    {
        $saisies = SaisieNote::where('enseignant_id', $request->user()->id)
            ->whereIn('statut', ['en_cours', 'rejetee'])
            ->with(['classe:id,nom', 'matiere:id,nom', 'periode:id,nom'])
            ->orderByDesc('updated_at')
            ->get();

        $resultat = $saisies->map(function (SaisieNote $saisie) {
            $nbEleves = Eleve::where('ecole_id', $saisie->ecole_id)
                ->whereHas('inscriptions', fn ($q) => $q
                    ->where('classe_id', $saisie->classe_id)
                    ->where('annee_academique_id', $saisie->annee_scolaire_id))
                ->count();

            $nbNotesSaisies = $saisie->notes()->count();
            $attendu = $nbEleves * 2; // devoir + composition par élève

            return [
                'id' => $saisie->id,
                'classe_id' => $saisie->classe_id,
                'classe_nom' => $saisie->classe->nom,
                'matiere_id' => $saisie->matiere_id,
                'matiere_nom' => $saisie->matiere->nom,
                'periode_id' => $saisie->periode_id,
                'periode_nom' => $saisie->periode->nom,
                'statut' => $saisie->statut,
                'nb_eleves' => $nbEleves,
                'nb_notes_saisies' => $nbNotesSaisies,
                'pourcentage_completion' => $attendu > 0
                    ? round(min($nbNotesSaisies, $attendu) / $attendu * 100, 1)
                    : 0,
            ];
        });

        return response()->json(['saisies' => $resultat]);
    }

    // Seul l'enseignant propriétaire de la saisie ou un membre de la
    // direction peut la consulter/manipuler.
    private function autoriserAcces(Request $request, SaisieNote $saisie): void
    {
        $utilisateur = $request->user();
        $estGestionnaire = in_array($utilisateur->role, ['directeur', 'censeur']);

        abort_unless($saisie->enseignant_id === $utilisateur->id || $estGestionnaire, 403,
            "Vous n'êtes pas autorisé à accéder à cette saisie.");
    }
}
