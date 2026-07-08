<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Classe;
use App\Models\ClasseMatiere;
use App\Models\Eleve;
use App\Models\Evaluation;
use App\Models\Matiere;
use App\Models\NoteEvaluation;
use App\Models\PeriodeAcademique;
use App\Services\MoyenneCalculService;
use Illuminate\Http\Request;

class EvaluationController extends Controller
{
    // Liste des évaluations filtrées par classe/matière/période
    public function index(Request $request)
    {
        $request->validate([
            'classe_id'  => 'required|integer',
            'matiere_id' => 'nullable|integer',
            'periode_id' => 'nullable|integer',
        ]);

        $classe = Classe::where('id', $request->classe_id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $evaluations = Evaluation::where('classe_id', $classe->id)
            ->when($request->matiere_id, fn($q) => $q->where('matiere_id', $request->matiere_id))
            ->when($request->periode_id, fn($q) => $q->where('periode_id', $request->periode_id))
            ->with(['matiere', 'periode', 'enseignant', 'notes.eleve'])
            ->orderBy('date_evaluation')
            ->get()
            ->map(function ($evaluation) {
                return [
                    'id'              => $evaluation->id,
                    'type'            => $evaluation->type,
                    'numero'          => $evaluation->numero,
                    'libelle'         => $evaluation->libelle,
                    'date_evaluation' => $evaluation->date_evaluation,
                    'matiere_id'      => $evaluation->matiere_id,
                    'matiere_nom'     => $evaluation->matiere->nom,
                    'periode_id'      => $evaluation->periode_id,
                    'periode_nom'     => $evaluation->periode->nom,
                    'enseignant_nom'  => $evaluation->enseignant->name,
                    'notes'           => $evaluation->notes->map(fn($note) => [
                        'eleve_id' => $note->eleve_id,
                        'nom'      => $note->eleve->nom,
                        'prenom'   => $note->eleve->prenom,
                        'valeur'   => $note->valeur,
                    ]),
                ];
            });

        return response()->json($evaluations);
    }

    // Créer une évaluation (devoir ou composition)
    public function creer(Request $request)
    {
        $request->validate([
            'classe_id'       => 'required|integer',
            'matiere_id'      => 'required|integer',
            'periode_id'      => 'required|integer',
            'type'            => 'required|in:devoir,composition',
            'numero'          => 'nullable|integer|min:1',
            'libelle'         => 'required|string|max:191',
            'date_evaluation' => 'required|date',
        ]);

        $ecoleId = $request->user()->ecole_id;

        Classe::where('id', $request->classe_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        Matiere::where('id', $request->matiere_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('id', $request->periode_id)
            ->firstOrFail();

        $evaluation = Evaluation::create([
            'classe_id'       => $request->classe_id,
            'matiere_id'      => $request->matiere_id,
            'periode_id'      => $request->periode_id,
            'enseignant_id'   => $request->user()->id,
            'type'            => $request->type,
            'numero'          => $request->numero ?? 1,
            'libelle'         => $request->libelle,
            'date_evaluation' => $request->date_evaluation,
        ]);

        return response()->json([
            'message'    => 'Évaluation créée avec succès',
            'evaluation' => $evaluation,
        ], 201);
    }

    // Enregistrer les notes de tous les élèves pour une évaluation
    public function saisirNotes(Request $request, $id)
    {
        $request->validate([
            'notes'             => 'required|array',
            'notes.*.eleve_id'  => 'required|integer',
            'notes.*.valeur'    => 'required|numeric|min:0|max:20',
        ]);

        $evaluation = Evaluation::where('id', $id)
            ->whereHas('classe', function ($q) use ($request) {
                $q->where('ecole_id', $request->user()->ecole_id);
            })
            ->firstOrFail();

        foreach ($request->notes as $note) {
            NoteEvaluation::updateOrCreate(
                [
                    'evaluation_id' => $evaluation->id,
                    'eleve_id'      => $note['eleve_id'],
                ],
                [
                    'valeur' => $note['valeur'],
                ]
            );
        }

        return response()->json(['message' => 'Notes enregistrées avec succès']);
    }

    // Moyenne finale d'un élève pour une matière/période
    public function calculerMoyenne(Request $request)
    {
        $request->validate([
            'classe_id'  => 'required|integer',
            'matiere_id' => 'required|integer',
            'periode_id' => 'required|integer',
            'eleve_id'   => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        Classe::where('id', $request->classe_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $eleve = Eleve::where('id', $request->eleve_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $resultat = $this->moyenneEleveMatiere(
            $request->classe_id,
            $request->matiere_id,
            $request->periode_id,
            $eleve->id
        );

        return response()->json(array_merge(['eleve_id' => $eleve->id], $resultat));
    }

    // Moyennes de tous les élèves d'une classe, toutes matières, pour une période
    public function moyennesClasse(Request $request)
    {
        $request->validate([
            'classe_id'  => 'required|integer',
            'periode_id' => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $classe = Classe::where('id', $request->classe_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $periode = PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('id', $request->periode_id)
            ->firstOrFail();

        $eleves = Eleve::where('ecole_id', $ecoleId)
            ->whereHas('inscriptions', function ($q) use ($classe, $periode) {
                $q->where('classe_id', $classe->id)
                  ->where('annee_academique_id', $periode->annee_academique_id);
            })
            ->orderBy('nom')
            ->get();

        $matieresClasse = ClasseMatiere::where('classe_id', $classe->id)
            ->with('matiere')
            ->get();

        $evaluations = Evaluation::where('classe_id', $classe->id)
            ->where('periode_id', $periode->id)
            ->with('notes')
            ->get()
            ->groupBy('matiere_id');

        $resultats = $eleves->map(function ($eleve) use ($matieresClasse, $evaluations) {
            $totalPoints       = 0;
            $totalCoefficients = 0;

            $matieres = $matieresClasse->map(function ($classeMatiere) use ($eleve, $evaluations, &$totalPoints, &$totalCoefficients) {
                $evalsMatiere = $evaluations->get($classeMatiere->matiere_id, collect());

                $notesDevoirs    = [];
                $noteComposition = null;

                foreach ($evalsMatiere as $evaluation) {
                    $note = $evaluation->notes->firstWhere('eleve_id', $eleve->id);
                    if (!$note) {
                        continue;
                    }
                    if ($evaluation->type === 'devoir') {
                        $notesDevoirs[] = $note->valeur;
                    } else {
                        $noteComposition = $note->valeur;
                    }
                }

                $moyenneFinale = MoyenneCalculService::moyenneFinale($notesDevoirs, $noteComposition);

                if ($moyenneFinale !== null) {
                    $totalPoints       += $moyenneFinale * $classeMatiere->coefficient;
                    $totalCoefficients += $classeMatiere->coefficient;
                }

                return [
                    'matiere_id'       => $classeMatiere->matiere_id,
                    'matiere_nom'      => $classeMatiere->matiere->nom,
                    'coefficient'      => $classeMatiere->coefficient,
                    'moyenne_devoirs'  => MoyenneCalculService::moyenneDevoirs($notesDevoirs),
                    'note_composition' => $noteComposition,
                    'moyenne_finale'   => $moyenneFinale,
                ];
            });

            return [
                'eleve_id'         => $eleve->id,
                'nom'              => $eleve->nom,
                'prenom'           => $eleve->prenom,
                'matricule'        => $eleve->matricule,
                'matieres'         => $matieres,
                'moyenne_generale' => $totalCoefficients > 0
                    ? round($totalPoints / $totalCoefficients, 2)
                    : null,
            ];
        });

        return response()->json([
            'classe_id'  => $classe->id,
            'periode_id' => $periode->id,
            'eleves'     => $resultats,
        ]);
    }

    // Moyenne finale d'un élève pour une matière/période donnée
    private function moyenneEleveMatiere(int $classeId, int $matiereId, int $periodeId, int $eleveId): array
    {
        $evaluations = Evaluation::where('classe_id', $classeId)
            ->where('matiere_id', $matiereId)
            ->where('periode_id', $periodeId)
            ->with(['notes' => fn($q) => $q->where('eleve_id', $eleveId)])
            ->get();

        $notesDevoirs    = [];
        $noteComposition = null;

        foreach ($evaluations as $evaluation) {
            $note = $evaluation->notes->first();
            if (!$note) {
                continue;
            }
            if ($evaluation->type === 'devoir') {
                $notesDevoirs[] = $note->valeur;
            } else {
                $noteComposition = $note->valeur;
            }
        }

        $moyenneDevoirs = MoyenneCalculService::moyenneDevoirs($notesDevoirs);
        $moyenneFinale  = MoyenneCalculService::moyenneFinale($notesDevoirs, $noteComposition);

        $classeMatiere = ClasseMatiere::where('classe_id', $classeId)
            ->where('matiere_id', $matiereId)
            ->first();

        $coefficient = $classeMatiere->coefficient
            ?? Matiere::find($matiereId)?->coefficient
            ?? 1;

        return [
            'moyenne_devoirs'  => $moyenneDevoirs,
            'note_composition' => $noteComposition,
            'moyenne_finale'   => $moyenneFinale,
            'coefficient'      => $coefficient,
            'points'           => $moyenneFinale !== null ? round($moyenneFinale * $coefficient, 2) : null,
        ];
    }

}
