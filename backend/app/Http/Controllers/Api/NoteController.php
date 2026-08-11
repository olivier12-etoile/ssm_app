<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ClasseMatiere;
use App\Models\Eleve;
use App\Models\Note;
use App\Models\PeriodeAcademique;
use App\Models\SaisieNote;
use App\Services\NoteCalculService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class NoteController extends Controller
{
    public function __construct(private NoteCalculService $noteCalcul)
    {
    }

    // POST /notes
    // Enregistre ou met à jour (upsert sur élève/matière/période/type) une
    // note en brouillon, pendant la saisie.
    public function store(Request $request)
    {
        $data = $request->validate([
            'eleve_id' => 'required|integer',
            'matiere_id' => 'required|integer',
            'classe_id' => 'required|integer',
            'periode_id' => 'required|integer',
            'type_evaluation' => 'required|in:devoir,composition',
            'valeur' => 'required|numeric|min:0|max:20',
        ]);

        $ecoleId = $request->user()->ecole_id;
        $enseignantId = $request->user()->id;

        Eleve::where('id', $data['eleve_id'])->where('ecole_id', $ecoleId)->firstOrFail();

        $classeMatiere = ClasseMatiere::where('classe_id', $data['classe_id'])
            ->where('matiere_id', $data['matiere_id'])
            ->first();

        if (!$classeMatiere) {
            return response()->json(['message' => "Cette matière n'est pas rattachée à cette classe."], 422);
        }

        if ($erreur = $this->verifierSaisieModifiable($ecoleId, $enseignantId, $data['classe_id'], $data['matiere_id'], $data['periode_id'])) {
            return $erreur;
        }

        $anneeScolaireId = PeriodeAcademique::findOrFail($data['periode_id'])->annee_academique_id;

        $note = Note::updateOrCreate(
            [
                'eleve_id' => $data['eleve_id'],
                'matiere_id' => $data['matiere_id'],
                'periode_id' => $data['periode_id'],
                'type_evaluation' => $data['type_evaluation'],
            ],
            [
                'ecole_id' => $ecoleId,
                'classe_id' => $data['classe_id'],
                'annee_scolaire_id' => $anneeScolaireId,
                'valeur' => $data['valeur'],
                'coefficient' => $classeMatiere->coefficient,
                'saisi_par' => $enseignantId,
                'statut' => 'brouillon',
                'motif_rejet' => null,
            ]
        );

        return response()->json(['message' => 'Note enregistrée', 'note' => $note], 201);
    }

    // POST /notes/bulk
    // Enregistrement en masse : toutes les notes d'une classe pour une
    // matière/période, en un seul appel.
    public function storeBulk(Request $request)
    {
        $data = $request->validate([
            'classe_id' => 'required|integer',
            'matiere_id' => 'required|integer',
            'periode_id' => 'required|integer',
            'notes' => 'required|array|min:1',
            'notes.*.eleve_id' => 'required|integer',
            'notes.*.type_evaluation' => 'required|in:devoir,composition',
            'notes.*.valeur' => 'required|numeric|min:0|max:20',
        ]);

        $ecoleId = $request->user()->ecole_id;
        $enseignantId = $request->user()->id;

        $classeMatiere = ClasseMatiere::where('classe_id', $data['classe_id'])
            ->where('matiere_id', $data['matiere_id'])
            ->first();

        if (!$classeMatiere) {
            return response()->json(['message' => "Cette matière n'est pas rattachée à cette classe."], 422);
        }

        if ($erreur = $this->verifierSaisieModifiable($ecoleId, $enseignantId, $data['classe_id'], $data['matiere_id'], $data['periode_id'])) {
            return $erreur;
        }

        $idsEleves = collect($data['notes'])->pluck('eleve_id')->unique();
        $idsValides = Eleve::where('ecole_id', $ecoleId)->whereIn('id', $idsEleves)->pluck('id');

        if ($idsEleves->diff($idsValides)->isNotEmpty()) {
            return response()->json(['message' => "Certains élèves n'appartiennent pas à votre école."], 422);
        }

        $anneeScolaireId = PeriodeAcademique::findOrFail($data['periode_id'])->annee_academique_id;

        $notesEnregistrees = DB::transaction(function () use ($data, $ecoleId, $enseignantId, $anneeScolaireId, $classeMatiere) {
            $resultat = [];

            foreach ($data['notes'] as $ligne) {
                $resultat[] = Note::updateOrCreate(
                    [
                        'eleve_id' => $ligne['eleve_id'],
                        'matiere_id' => $data['matiere_id'],
                        'periode_id' => $data['periode_id'],
                        'type_evaluation' => $ligne['type_evaluation'],
                    ],
                    [
                        'ecole_id' => $ecoleId,
                        'classe_id' => $data['classe_id'],
                        'annee_scolaire_id' => $anneeScolaireId,
                        'valeur' => $ligne['valeur'],
                        'coefficient' => $classeMatiere->coefficient,
                        'saisi_par' => $enseignantId,
                        'statut' => 'brouillon',
                        'motif_rejet' => null,
                    ]
                );
            }

            return $resultat;
        });

        return response()->json([
            'message' => count($notesEnregistrees) . ' note(s) enregistrée(s)',
            'notes' => $notesEnregistrees,
        ], 201);
    }

    // PUT /notes/{id}
    // Corrige la valeur d'une note déjà enregistrée (uniquement si encore
    // modifiable : brouillon et saisie non verrouillée).
    public function update(Request $request, $id)
    {
        $note = Note::findOrFail($id);

        if (!$note->modifiable) {
            return response()->json(['message' => "Cette note n'est plus modifiable."], 403);
        }

        $data = $request->validate([
            'valeur' => 'required|numeric|min:0|max:20',
        ]);

        $note->update(['valeur' => $data['valeur']]);

        return response()->json(['message' => 'Note modifiée', 'note' => $note->fresh()]);
    }

    // DELETE /notes/{id}
    // Supprime une note en brouillon (jamais une note validée).
    public function destroy($id)
    {
        $note = Note::findOrFail($id);

        if ($note->statut !== 'brouillon') {
            return response()->json(['message' => 'Seule une note en brouillon peut être supprimée.'], 403);
        }

        if (!$note->modifiable) {
            return response()->json(['message' => "Cette note n'est plus modifiable (saisie verrouillée)."], 403);
        }

        $note->delete();

        return response()->json(['message' => 'Note supprimée']);
    }

    // GET /notes/statistiques
    public function statistiques(Request $request)
    {
        $data = $request->validate([
            'classe_id' => 'required|integer',
            'matiere_id' => 'required|integer',
            'periode_id' => 'required|integer',
        ]);

        return response()->json([
            'moyenne_classe' => $this->noteCalcul->moyenneMatiere($data['classe_id'], $data['matiere_id'], $data['periode_id']),
            'meilleure_note' => $this->noteCalcul->meilleureNote($data['classe_id'], $data['matiere_id'], $data['periode_id']),
            'plus_faible_note' => $this->noteCalcul->plusFaibleNote($data['classe_id'], $data['matiere_id'], $data['periode_id']),
            'taux_reussite' => $this->noteCalcul->tauxReussite($data['classe_id'], $data['matiere_id'], $data['periode_id']),
            'anomalies' => $this->noteCalcul->detecterAnomalies($data['classe_id'], $data['matiere_id'], $data['periode_id']),
        ]);
    }

    // Une note ne peut être créée/modifiée que si sa saisie existe déjà
    // (l'enseignant a démarré la session via SaisieNoteController::demarrer),
    // a pour statut "en_cours" ou "rejetee", et n'est pas verrouillée.
    private function verifierSaisieModifiable(
        int $ecoleId,
        int $enseignantId,
        int $classeId,
        int $matiereId,
        int $periodeId
    ): ?JsonResponse {
        $saisie = SaisieNote::where('ecole_id', $ecoleId)
            ->where('enseignant_id', $enseignantId)
            ->where('classe_id', $classeId)
            ->where('matiere_id', $matiereId)
            ->where('periode_id', $periodeId)
            ->first();

        if (!$saisie) {
            return response()->json([
                'message' => "Veuillez d'abord démarrer la saisie pour cette classe, cette matière et cette période.",
            ], 422);
        }

        if (!in_array($saisie->statut, ['en_cours', 'rejetee'])) {
            return response()->json([
                'message' => "Cette saisie n'est plus modifiable (statut actuel : {$saisie->statut}).",
            ], 403);
        }

        if ($saisie->estVerrouillee()) {
            return response()->json([
                'message' => 'Cette saisie est verrouillée. Contactez la direction pour la faire déverrouiller.',
            ], 403);
        }

        return null;
    }
}
