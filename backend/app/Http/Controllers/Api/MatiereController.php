<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Evaluation;
use App\Models\Matiere;
use App\Models\Note;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MatiereController extends Controller
{
    // ── 1. Liste des matières de l'école ──────────────────────────
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $colonnesTri = ['nom', 'created_at'];
        $tri = in_array($request->get('tri'), $colonnesTri) ? $request->get('tri') : 'nom';
        $direction = $request->get('direction') === 'desc' ? 'desc' : 'asc';

        $matieres = Matiere::where('ecole_id', $ecoleId)
            ->when($request->search, fn($q) => $q->where('nom', 'like', '%' . $request->search . '%'))
            ->orderBy($tri, $direction)
            ->get();

        $matiereIds = $matieres->pluck('id');

        // Nombre de classes distinctes utilisant chaque matière.
        $nombreClasses = DB::table('classe_matiere')
            ->whereIn('matiere_id', $matiereIds)
            ->select('matiere_id', DB::raw('count(distinct classe_id) as total'))
            ->groupBy('matiere_id')
            ->pluck('total', 'matiere_id');

        // Enseignants distincts par matière.
        $enseignantsParMatiere = DB::table('enseignant_classe_matiere')
            ->whereIn('enseignant_classe_matiere.matiere_id', $matiereIds)
            ->join('users', 'users.id', '=', 'enseignant_classe_matiere.enseignant_id')
            ->select('enseignant_classe_matiere.matiere_id', 'users.id', 'users.name')
            ->distinct()
            ->get()
            ->groupBy('matiere_id');

        // Moyenne générale de chaque matière (notes validées de l'école).
        $moyennesParMatiere = Note::whereIn('matiere_id', $matiereIds)
            ->where('statut', 'valide')
            ->select('matiere_id', DB::raw('AVG(valeur) as moyenne'))
            ->groupBy('matiere_id')
            ->pluck('moyenne', 'matiere_id');

        $matieres->each(function ($matiere) use ($nombreClasses, $enseignantsParMatiere, $moyennesParMatiere) {
            $matiere->nombre_classes = $nombreClasses[$matiere->id] ?? 0;
            $matiere->enseignants = ($enseignantsParMatiere[$matiere->id] ?? collect())
                ->map(fn($e) => ['id' => $e->id, 'name' => $e->name])
                ->values();
            $matiere->moyenne_generale = isset($moyennesParMatiere[$matiere->id])
                ? round($moyennesParMatiere[$matiere->id], 2)
                : null;
        });

        return response()->json($matieres);
    }

    // ── 2. Créer une matière ───────────────────────────────────────
    public function store(Request $request)
    {
        $request->validate([
            'nom'         => 'required|string|max:100',
            'code'        => 'nullable|string|max:10',
            'couleur'     => 'nullable|string|max:20',
            'coefficient' => 'nullable|numeric|min:0.5',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $existe = Matiere::where('ecole_id', $ecoleId)
            ->where('nom', $request->nom)
            ->exists();

        if ($existe) {
            return response()->json([
                'message' => "Une matière nommée \"{$request->nom}\" existe déjà",
            ], 409);
        }

        $matiere = Matiere::create([
            'ecole_id'    => $ecoleId,
            'nom'         => $request->nom,
            'code'        => $request->code,
            'couleur'     => $request->couleur,
            'coefficient' => $request->coefficient ?? 1,
        ]);

        return response()->json([
            'message' => 'Matière créée avec succès',
            'matiere' => $matiere,
        ], 201);
    }

    // ── 3. Modifier une matière ────────────────────────────────────
    public function update(Request $request, $id)
    {
        $matiere = Matiere::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $request->validate([
            'nom'         => 'sometimes|string|max:100',
            'code'        => 'nullable|string|max:10',
            'couleur'     => 'nullable|string|max:20',
            'coefficient' => 'nullable|numeric|min:0.5',
        ]);

        if ($request->has('nom')) {
            $existe = Matiere::where('ecole_id', $request->user()->ecole_id)
                ->where('nom', $request->nom)
                ->where('id', '!=', $matiere->id)
                ->exists();

            if ($existe) {
                return response()->json([
                    'message' => "Une matière nommée \"{$request->nom}\" existe déjà",
                ], 409);
            }
        }

        $matiere->update($request->only(['nom', 'code', 'couleur', 'coefficient']));

        return response()->json([
            'message' => 'Matière modifiée avec succès',
            'matiere' => $matiere,
        ]);
    }

    // ── 4. Supprimer une matière ───────────────────────────────────
    public function destroy(Request $request, $id)
    {
        $matiere = Matiere::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $utiliseeDansClasses = DB::table('classe_matiere')->where('matiere_id', $matiere->id)->exists();
        $utiliseeDansNotes   = Note::where('matiere_id', $matiere->id)->exists();

        if ($utiliseeDansClasses || $utiliseeDansNotes) {
            $raisons = [];
            if ($utiliseeDansClasses) $raisons[] = 'affectée à au moins une classe';
            if ($utiliseeDansNotes)   $raisons[] = 'utilisée dans des notes existantes';

            return response()->json([
                'message' => 'Impossible de supprimer cette matière : elle est ' . implode(' et ', $raisons) . '.',
            ], 409);
        }

        $matiere->delete();

        return response()->json(['message' => 'Matière supprimée avec succès']);
    }

    // ── 5. Statistiques par matière ─────────────────────────────────
    public function statistiques(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        $matieres = Matiere::where('ecole_id', $ecoleId)->orderBy('nom')->get();

        $resultats = [];

        foreach ($matieres as $matiere) {
            $moyennesParClasse = DB::table('notes')
                ->join('inscriptions', 'notes.eleve_id', '=', 'inscriptions.eleve_id')
                ->join('classes', 'inscriptions.classe_id', '=', 'classes.id')
                ->where('classes.ecole_id', $ecoleId)
                ->where('notes.matiere_id', $matiere->id)
                ->where('notes.statut', 'valide')
                ->select('classes.id as classe_id', 'classes.nom as classe_nom', DB::raw('ROUND(AVG(notes.valeur), 2) as moyenne'))
                ->groupBy('classes.id', 'classes.nom')
                ->get();

            $meilleureClasse    = $moyennesParClasse->sortByDesc('moyenne')->first();
            $classeEnDifficulte = $moyennesParClasse->where('moyenne', '<', 10)->sortBy('moyenne')->first();

            $nombreEvaluations = Evaluation::where('matiere_id', $matiere->id)
                ->whereHas('classe', fn($q) => $q->where('ecole_id', $ecoleId))
                ->count();

            $moyenneGenerale = DB::table('notes')
                ->join('inscriptions', 'notes.eleve_id', '=', 'inscriptions.eleve_id')
                ->join('classes', 'inscriptions.classe_id', '=', 'classes.id')
                ->where('classes.ecole_id', $ecoleId)
                ->where('notes.matiere_id', $matiere->id)
                ->where('notes.statut', 'valide')
                ->avg('notes.valeur');

            $resultats[] = [
                'matiere_id'           => $matiere->id,
                'matiere_nom'          => $matiere->nom,
                'moyenne_generale'     => $moyenneGenerale ? round($moyenneGenerale, 2) : null,
                'moyennes_par_classe'  => $moyennesParClasse->values(),
                'meilleure_classe'     => $meilleureClasse,
                'classe_en_difficulte' => $classeEnDifficulte,
                'nombre_evaluations'   => $nombreEvaluations,
            ];
        }

        $avecMoyenne = collect($resultats)->filter(fn($r) => $r['moyenne_generale'] !== null);

        return response()->json([
            'matieres'               => $resultats,
            'matiere_plus_difficile' => $avecMoyenne->sortBy('moyenne_generale')->first(),
            'matiere_plus_facile'    => $avecMoyenne->sortByDesc('moyenne_generale')->first(),
        ]);
    }
}