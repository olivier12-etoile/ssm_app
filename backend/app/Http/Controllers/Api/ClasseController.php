<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Absence;
use App\Models\Classe;
use App\Models\Eleve;
use App\Models\Inscription;
use App\Models\Note;
use App\Models\Paiement;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

class ClasseController extends Controller
{
    // ── 1. Liste des classes de l'école ──────────────────────────
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $colonnesTri = ['nom', 'niveau', 'effectif', 'created_at'];
        $tri = in_array($request->get('tri'), $colonnesTri) ? $request->get('tri') : 'nom';
        $direction = $request->get('direction') === 'desc' ? 'desc' : 'asc';

        $query = Classe::where('ecole_id', $ecoleId)
            ->withCount(['inscriptions as nombre_eleves', 'matieres as nombre_matieres'])
            ->addSelect([
                'nombre_enseignants' => DB::table('enseignant_classe_matiere')
                    ->selectRaw('count(distinct enseignant_id)')
                    ->whereColumn('classe_id', 'classes.id'),
            ])
            ->with([
                'professeurPrincipal:id,name,photo_path',
                'annee:id,libelle',
            ])
            ->when($request->statut, fn($q) => $q->where('statut', $request->statut))
            ->when($request->niveau, fn($q) => $q->where('niveau', $request->niveau))
            ->when($request->annee_id, fn($q) => $q->where('annee_academique_id', $request->annee_id))
            ->when($request->search, function ($q) use ($request) {
                $recherche = $request->search;
                $q->where(function ($qq) use ($recherche) {
                    $qq->where('nom', 'like', "%{$recherche}%")
                       ->orWhere('niveau', 'like', "%{$recherche}%")
                       ->orWhere('serie', 'like', "%{$recherche}%");
                });
            });

        $query->orderBy($tri === 'effectif' ? 'nombre_eleves' : $tri, $direction);

        return response()->json($query->paginate(20));
    }

    // ── 2. Créer une classe ───────────────────────────────────────
    public function store(Request $request)
    {
        $data = $request->validate([
            'nom'                     => 'required|string|max:50',
            'niveau'                  => 'required|string|max:20',
            'serie'                   => 'nullable|string|max:20',
            'salle'                   => 'nullable|string|max:50',
            'capacite_max'            => 'nullable|integer|min:1',
            'statut'                  => 'nullable|in:active,inactive',
            'professeur_principal_id' => 'nullable|integer|exists:users,id',
            'annee_academique_id'     => 'nullable|integer|exists:annees_academiques,id',
        ]);

        $classe = Classe::create([
            'ecole_id'                => $request->user()->ecole_id,
            'nom'                     => $data['nom'],
            'niveau'                  => $data['niveau'],
            'serie'                   => $data['serie'] ?? null,
            'salle'                   => $data['salle'] ?? null,
            'capacite_max'            => $data['capacite_max'] ?? 50,
            'statut'                  => $data['statut'] ?? 'active',
            'professeur_principal_id' => $data['professeur_principal_id'] ?? null,
            'annee_academique_id'     => $data['annee_academique_id'] ?? null,
        ]);

        return response()->json([
            'message' => 'Classe créée avec succès',
            'classe'  => $classe,
        ], 201);
    }

    // ── 3. Fiche complète d'une classe ────────────────────────────
    public function show(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;

        $classe = Classe::where('id', $id)
            ->where('ecole_id', $ecoleId)
            ->with(['professeurPrincipal:id,name,photo_path', 'annee:id,libelle'])
            ->withCount('inscriptions as nombre_eleves')
            ->firstOrFail();

        $enseignants = DB::table('enseignant_classe_matiere')
            ->where('enseignant_classe_matiere.classe_id', $classe->id)
            ->join('users', 'users.id', '=', 'enseignant_classe_matiere.enseignant_id')
            ->join('matieres', 'matieres.id', '=', 'enseignant_classe_matiere.matiere_id')
            ->leftJoin('classe_matiere', function ($join) {
                $join->on('classe_matiere.classe_id', '=', 'enseignant_classe_matiere.classe_id')
                     ->on('classe_matiere.matiere_id', '=', 'enseignant_classe_matiere.matiere_id');
            })
            ->select(
                'users.id as enseignant_id',
                'users.name as enseignant_nom',
                'users.telephone as enseignant_telephone',
                'users.photo_path as enseignant_photo_path',
                'matieres.id as matiere_id',
                'matieres.nom as matiere_nom',
                'classe_matiere.coefficient',
            )
            ->get()
            ->map(function ($e) {
                $e->enseignant_photo_url = $e->enseignant_photo_path
                    ? asset('storage/' . $e->enseignant_photo_path)
                    : null;
                unset($e->enseignant_photo_path);
                return $e;
            });

        $matieres = DB::table('classe_matiere')
            ->where('classe_matiere.classe_id', $classe->id)
            ->join('matieres', 'matieres.id', '=', 'classe_matiere.matiere_id')
            ->select(
                'classe_matiere.id',
                'matieres.id as matiere_id',
                'matieres.nom as matiere_nom',
                'classe_matiere.coefficient',
            )
            ->orderBy('matieres.nom')
            ->get();

        $eleveIds = Inscription::where('classe_id', $classe->id)->pluck('eleve_id');

        $garcons = Inscription::where('classe_id', $classe->id)
            ->whereHas('eleve', fn($q) => $q->where('sexe', 'M'))
            ->count();
        $filles = Inscription::where('classe_id', $classe->id)
            ->whereHas('eleve', fn($q) => $q->where('sexe', 'F'))
            ->count();

        $moyenneGenerale = Note::whereIn('eleve_id', $eleveIds)
            ->where('statut', 'valide')
            ->avg('valeur');

        $moyennesParEleve = Note::whereIn('eleve_id', $eleveIds)
            ->where('statut', 'valide')
            ->select('eleve_id', DB::raw('AVG(valeur) as moyenne'))
            ->groupBy('eleve_id')
            ->pluck('moyenne', 'eleve_id');

        $tauxReussite = $moyennesParEleve->isEmpty()
            ? 0
            : round($moyennesParEleve->filter(fn($m) => $m >= 10)->count() / $moyennesParEleve->count() * 100, 1);

        $idsEnDifficulte = $moyennesParEleve->filter(fn($m) => $m < 8)->keys();

        $elevesEnDifficulte = Eleve::whereIn('id', $idsEnDifficulte)
            ->get(['id', 'nom', 'prenom'])
            ->map(function ($eleve) use ($moyennesParEleve) {
                $eleve->moyenne = round($moyennesParEleve[$eleve->id], 2);
                return $eleve;
            })
            ->values();

        $totalAbsences = Absence::where('classe_id', $classe->id)->count();

        $totalPaiements = Paiement::whereIn('eleve_id', $eleveIds)->sum('montant');

        return response()->json([
            'classe'       => $classe,
            'enseignants'  => $enseignants,
            'matieres'     => $matieres,
            'statistiques' => [
                'garcons'                    => $garcons,
                'filles'                     => $filles,
                'moyenne_generale'           => $moyenneGenerale ? round($moyenneGenerale, 2) : null,
                'taux_reussite'              => $tauxReussite,
                'total_absences'             => $totalAbsences,
                'total_paiements'            => $totalPaiements,
                'nombre_eleves_en_difficulte' => $elevesEnDifficulte->count(),
                'eleves_en_difficulte'       => $elevesEnDifficulte,
            ],
        ]);
    }

    // ── 4. Modifier une classe ────────────────────────────────────
    public function update(Request $request, $id)
    {
        $classe = Classe::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $data = $request->validate([
            'nom'                     => 'required|string|max:50',
            'niveau'                  => 'required|string|max:20',
            'serie'                   => 'nullable|string|max:20',
            'salle'                   => 'nullable|string|max:50',
            'capacite_max'            => 'nullable|integer|min:1',
            'statut'                  => 'nullable|in:active,inactive',
            'professeur_principal_id' => 'nullable|integer|exists:users,id',
            'annee_academique_id'     => 'nullable|integer|exists:annees_academiques,id',
        ]);

        $classe->update($data);

        return response()->json([
            'message' => 'Classe modifiée avec succès',
            'classe'  => $classe,
        ]);
    }

    // ── 5. Archiver une classe ────────────────────────────────────
    public function archiverClasse($id, Request $request)
    {
        $classe = Classe::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $classe->update(['statut' => 'inactive']);

        return response()->json(['message' => 'Classe archivée']);
    }

    // ── 6. Réactiver une classe ───────────────────────────────────
    public function activerClasse($id, Request $request)
    {
        $classe = Classe::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $classe->update(['statut' => 'active']);

        return response()->json(['message' => 'Classe réactivée']);
    }

    // ── 7. Transférer un élève vers une autre classe ──────────────
    public function transfererEleve(Request $request)
    {
        $request->validate([
            'eleve_id'              => 'required|integer',
            'classe_source_id'      => 'required|integer',
            'classe_destination_id' => 'required|integer|different:classe_source_id',
        ]);

        $ecoleId = $request->user()->ecole_id;

        Classe::where('id', $request->classe_destination_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $inscription = Inscription::where('eleve_id', $request->eleve_id)
            ->where('classe_id', $request->classe_source_id)
            ->whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
            ->firstOrFail();

        $inscription->update(['classe_id' => $request->classe_destination_id]);

        return response()->json(['message' => 'Élève transféré avec succès']);
    }

    // ── 8. Exporter la liste des élèves en PDF ────────────────────
    public function exporterListePdf(Request $request, $id)
    {
        $ecole = $request->user()->ecole;

        $classe = Classe::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->with('annee:id,libelle')
            ->firstOrFail();

        $eleves = Eleve::whereHas('inscriptions', fn($q) => $q->where('classe_id', $classe->id))
            ->orderBy('nom')
            ->get();

        $pdf = Pdf::loadView('pdf.classe_liste_eleves', [
            'ecole' => [
                'nom'              => $ecole->nom,
                'code_ecole'       => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'classe'    => $classe,
            'eleves'    => $eleves,
            'genere_le' => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download('liste_eleves_' . str_replace(' ', '_', $classe->nom) . '.pdf');
    }

    // ── 9. Exporter la liste des élèves en Excel ──────────────────
    // Remarque : maatwebsite/excel n'est pas installé (conflit de version
    // avec phpoffice/phpspreadsheet ^5.9 déjà utilisé pour l'import
    // utilisateurs — voir décision précédente). Génération du .xlsx
    // directement via le writer de PhpSpreadsheet.
    public function exporterListeExcel(Request $request, $id)
    {
        $classe = Classe::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $eleves = Eleve::whereHas('inscriptions', fn($q) => $q->where('classe_id', $classe->id))
            ->orderBy('nom')
            ->get();

        $spreadsheet = new Spreadsheet();
        $feuille = $spreadsheet->getActiveSheet();
        $feuille->setTitle('Élèves');
        $feuille->fromArray(
            ['Matricule', 'Nom', 'Prénom', 'Sexe', 'Date de naissance', 'Téléphone parent'],
            null,
            'A1'
        );

        $ligne = 2;
        foreach ($eleves as $eleve) {
            $feuille->fromArray([
                $eleve->matricule,
                $eleve->nom,
                $eleve->prenom,
                $eleve->sexe,
                $eleve->date_naissance,
                $eleve->telephone_parent,
            ], null, "A{$ligne}");
            $ligne++;
        }

        $nomFichier = 'liste_eleves_' . str_replace(' ', '_', $classe->nom) . '.xlsx';
        $dossierTemp = storage_path('app/tmp');
        if (!is_dir($dossierTemp)) {
            mkdir($dossierTemp, 0755, true);
        }
        $cheminTemp = $dossierTemp . '/' . $nomFichier;

        (new Xlsx($spreadsheet))->save($cheminTemp);

        return response()->download($cheminTemp, $nomFichier)->deleteFileAfterSend(true);
    }
}
