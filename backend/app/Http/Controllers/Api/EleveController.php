<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Absence;
use App\Models\AnneeAcademique;
use App\Models\ChronologieEleve;
use App\Models\Classe;
use App\Models\ClasseMatiere;
use App\Models\DocumentEleve;
use App\Models\Eleve;
use App\Models\FraisScolaire;
use App\Models\Inscription;
use App\Models\Note;
use App\Models\Paiement;
use App\Models\ParentEleve;
use App\Models\PeriodeAcademique;
use App\Models\Sanction;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class EleveController extends Controller
{
    private const STATUTS = ['actif', 'suspendu', 'exclu', 'transfere', 'diplome', 'abandon'];

    // ════════════════════════════════════════════════════════════
    // 1. Tableau de bord
    // ════════════════════════════════════════════════════════════
    public function tableauDeBord(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $total = Eleve::where('ecole_id', $ecoleId)->count();
        $garcons = Eleve::where('ecole_id', $ecoleId)->where('sexe', 'M')->count();
        $filles = Eleve::where('ecole_id', $ecoleId)->where('sexe', 'F')->count();

        $nouveauxInscrits = Eleve::where('ecole_id', $ecoleId)
            ->whereMonth('created_at', now()->month)
            ->whereYear('created_at', now()->year)
            ->count();

        $parStatutBrut = Eleve::where('ecole_id', $ecoleId)
            ->select('statut', DB::raw('COUNT(*) as total'))
            ->groupBy('statut')
            ->pluck('total', 'statut');
        $parStatut = collect(self::STATUTS)->mapWithKeys(fn($s) => [$s => $parStatutBrut[$s] ?? 0]);

        $sansPhoto = Eleve::where('ecole_id', $ecoleId)->whereNull('photo_path')->count();
        $sansTelephoneParent = Eleve::where('ecole_id', $ecoleId)
            ->where(fn($q) => $q->whereNull('telephone_parent')->orWhere('telephone_parent', ''))
            ->count();

        $absentsAujourdhui = Absence::whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('date_absence', now()->format('Y-m-d'))
            ->distinct('eleve_id')
            ->count('eleve_id');

        $annee = AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->first();

        $reinscriptions = 0;
        $enRetardPaiement = 0;
        $enRegle = 0;
        $moyenneSup15 = 0;
        $enDifficulte = 0;
        $redoublants = 0;

        if ($annee) {
            $reinscriptions = Eleve::where('ecole_id', $ecoleId)
                ->whereHas('inscriptions', fn($q) => $q->where('annee_academique_id', $annee->id))
                ->whereHas('inscriptions', fn($q) => $q->where('annee_academique_id', '!=', $annee->id))
                ->count();

            $rapport = (new FraisScolaireController())->calculerRapportFinancier($ecoleId, $annee->id, null);
            $inscritsAnnee = Inscription::where('annee_academique_id', $annee->id)
                ->whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
                ->count();
            $enRetardPaiement = count($rapport['debiteurs']);
            $enRegle = max(0, $inscritsAnnee - $enRetardPaiement);

            $redoublants = Inscription::where('annee_academique_id', $annee->id)
                ->where('statut', 'redoublant')
                ->whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
                ->count();

            $moyennesParEleve = Note::whereHas('periode', fn($q) => $q->where('annee_academique_id', $annee->id))
                ->where('statut', 'valide')
                ->whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
                ->select('eleve_id', DB::raw('AVG(valeur) as moyenne'))
                ->groupBy('eleve_id')
                ->pluck('moyenne');

            $moyenneSup15 = $moyennesParEleve->filter(fn($m) => $m > 15)->count();
            $enDifficulte = $moyennesParEleve->filter(fn($m) => $m < 8)->count();
        }

        return response()->json([
            'total'                => $total,
            'garcons'              => $garcons,
            'filles'               => $filles,
            'nouveaux_inscrits'    => $nouveauxInscrits,
            'reinscriptions'       => $reinscriptions,
            'par_statut'           => $parStatut,
            'en_retard_paiement'   => $enRetardPaiement,
            'en_regle'             => $enRegle,
            'sans_photo'           => $sansPhoto,
            'sans_telephone_parent'=> $sansTelephoneParent,
            'absents_aujourd_hui'  => $absentsAujourdhui,
            'moyenne_sup_15'       => $moyenneSup15,
            'en_difficulte'        => $enDifficulte,
            'redoublants'          => $redoublants,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 2. Liste intelligente (par type d'alerte)
    // ════════════════════════════════════════════════════════════
    private const TYPES_LISTE_INTELLIGENTE = 'en_retard_paiement,en_regle,sans_photo,sans_telephone,'
        . 'absents_aujourd_hui,redoublants,suspendus,diplomes,transferes,abandons,'
        . 'moyenne_sup_15,en_difficulte';

    public function listeIntelligente(Request $request)
    {
        $request->validate(['type' => 'required|in:' . self::TYPES_LISTE_INTELLIGENTE]);

        $ecoleId = $request->user()->ecole_id;
        $resultat = $this->calculerListeIntelligente($ecoleId, $request->type);

        return response()->json([
            'type'    => $request->type,
            'total'   => $resultat['total'],
            'classes' => $resultat['classes'],
        ]);
    }

    // Exporte la liste intelligente en PDF.
    public function exporterListeIntelligentePdf(Request $request)
    {
        $request->validate(['type' => 'required|in:' . self::TYPES_LISTE_INTELLIGENTE]);

        $ecoleId = $request->user()->ecole_id;
        $ecole = $request->user()->ecole;
        $resultat = $this->calculerListeIntelligente($ecoleId, $request->type);

        $pdf = Pdf::loadView('pdf.liste_intelligente', [
            'ecole' => [
                'nom'              => $ecole->nom,
                'code_ecole'       => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'type'      => $request->type,
            'classes'   => $resultat['classes'],
            'total'     => $resultat['total'],
            'genere_le' => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download('liste_' . $request->type . '.pdf');
    }

    // Exporte la liste intelligente en CSV (compatible Excel).
    public function exporterListeIntelligenteExcel(Request $request)
    {
        $request->validate(['type' => 'required|in:' . self::TYPES_LISTE_INTELLIGENTE]);

        $ecoleId = $request->user()->ecole_id;
        $resultat = $this->calculerListeIntelligente($ecoleId, $request->type);

        $callback = function () use ($resultat) {
            $fichier = fopen('php://output', 'w');
            fwrite($fichier, "\xEF\xBB\xBF");
            fputcsv($fichier, ['Classe', 'Matricule', 'Nom', 'Prénom', 'Valeur']);

            foreach ($resultat['classes'] as $classeNom => $eleves) {
                foreach ($eleves as $e) {
                    fputcsv($fichier, [$classeNom, $e['matricule'], $e['nom'], $e['prenom'], $e['valeur']]);
                }
            }

            fclose($fichier);
        };

        return response()->stream($callback, 200, [
            'Content-Type'        => 'text/csv',
            'Content-Disposition' => 'attachment; filename="liste_' . $request->type . '.csv"',
        ]);
    }

    private function calculerListeIntelligente(int $ecoleId, string $type): array
    {
        $annee = AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->first();

        $eleveIds = collect();
        $valeurs = collect();

        switch ($type) {
            case 'en_retard_paiement':
            case 'en_regle':
                if ($annee) {
                    $rapport = (new FraisScolaireController())->calculerRapportFinancier($ecoleId, $annee->id, null);
                    if ($type === 'en_retard_paiement') {
                        foreach ($rapport['debiteurs'] as $d) {
                            $eleveIds->push($d['eleve_id']);
                            $valeurs[$d['eleve_id']] = $d['montant_restant'] . ' FCFA restants';
                        }
                    } else {
                        $debiteursIds = collect($rapport['debiteurs'])->pluck('eleve_id');
                        $eleveIds = Inscription::where('annee_academique_id', $annee->id)
                            ->whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
                            ->whereNotIn('eleve_id', $debiteursIds)
                            ->pluck('eleve_id');
                    }
                }
                break;

            case 'sans_photo':
                $eleveIds = Eleve::where('ecole_id', $ecoleId)->whereNull('photo_path')->pluck('id');
                break;

            case 'sans_telephone':
                $eleveIds = Eleve::where('ecole_id', $ecoleId)
                    ->where(fn($q) => $q->whereNull('telephone_parent')->orWhere('telephone_parent', ''))
                    ->pluck('id');
                break;

            case 'absents_aujourd_hui':
                $eleveIds = Absence::whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
                    ->where('date_absence', now()->format('Y-m-d'))
                    ->distinct()
                    ->pluck('eleve_id');
                break;

            case 'redoublants':
                if ($annee) {
                    $eleveIds = Inscription::where('annee_academique_id', $annee->id)
                        ->where('statut', 'redoublant')
                        ->whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
                        ->pluck('eleve_id');
                }
                break;

            case 'suspendus':
                $eleveIds = Eleve::where('ecole_id', $ecoleId)->where('statut', 'suspendu')->pluck('id');
                break;

            case 'diplomes':
                $eleveIds = Eleve::where('ecole_id', $ecoleId)->where('statut', 'diplome')->pluck('id');
                break;

            case 'transferes':
                $eleveIds = Eleve::where('ecole_id', $ecoleId)->where('statut', 'transfere')->pluck('id');
                break;

            case 'abandons':
                $eleveIds = Eleve::where('ecole_id', $ecoleId)->where('statut', 'abandon')->pluck('id');
                break;

            case 'moyenne_sup_15':
            case 'en_difficulte':
                if ($annee) {
                    $moyennes = Note::whereHas('periode', fn($q) => $q->where('annee_academique_id', $annee->id))
                        ->where('statut', 'valide')
                        ->whereHas('eleve', fn($q) => $q->where('ecole_id', $ecoleId))
                        ->select('eleve_id', DB::raw('AVG(valeur) as moyenne'))
                        ->groupBy('eleve_id')
                        ->get();

                    $filtre = $type === 'moyenne_sup_15'
                        ? $moyennes->filter(fn($m) => $m->moyenne > 15)
                        : $moyennes->filter(fn($m) => $m->moyenne < 8);

                    foreach ($filtre as $m) {
                        $eleveIds->push($m->eleve_id);
                        $valeurs[$m->eleve_id] = round($m->moyenne, 2) . '/20';
                    }
                }
                break;
        }

        $eleves = Eleve::whereIn('id', $eleveIds)
            ->with(['inscriptions' => fn($q) => $annee ? $q->where('annee_academique_id', $annee->id) : $q, 'inscriptions.classe'])
            ->orderBy('nom')
            ->get()
            ->map(function ($e) use ($valeurs) {
                $classe = optional($e->inscriptions->first())->classe;
                return [
                    'eleve_id'    => $e->id,
                    'nom'         => $e->nom,
                    'prenom'      => $e->prenom,
                    'matricule'   => $e->matricule,
                    'photo_url'   => $e->photo_url,
                    'classe_id'   => $classe?->id,
                    'classe_nom'  => $classe?->nom ?? 'Non affecté',
                    'statut'      => $e->statut,
                    'valeur'      => $valeurs[$e->id] ?? null,
                ];
            });

        return [
            'total'   => $eleves->count(),
            'classes' => $eleves->groupBy('classe_nom')->map(fn($l) => $l->values()),
        ];
    }

    // ════════════════════════════════════════════════════════════
    // 3. Liste paginée avec filtres
    // ════════════════════════════════════════════════════════════
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $query = Eleve::where('eleves.ecole_id', $ecoleId);

        if ($request->filled('sexe')) {
            $query->where('eleves.sexe', $request->sexe);
        }

        if ($request->filled('statut')) {
            $query->where('eleves.statut', $request->statut);
        }

        if ($request->filled('search')) {
            $recherche = $request->search;
            $query->where(function ($q) use ($recherche) {
                $q->where('eleves.nom', 'like', "%{$recherche}%")
                    ->orWhere('eleves.prenom', 'like', "%{$recherche}%")
                    ->orWhere('eleves.matricule', 'like', "%{$recherche}%");
            });
        }

        if ($request->filled('classe_id') || $request->filled('annee_id')) {
            $query->whereHas('inscriptions', function ($q) use ($request) {
                if ($request->filled('classe_id')) {
                    $q->where('classe_id', $request->classe_id);
                }
                if ($request->filled('annee_id')) {
                    $q->where('annee_academique_id', $request->annee_id);
                }
            });
        }

        $anneeId = $request->input('annee_id')
            ?? optional(AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->first())->id;

        if ($request->has('en_regle') && $anneeId) {
            $rapport = (new FraisScolaireController())->calculerRapportFinancier($ecoleId, $anneeId, null);
            $debiteursIds = collect($rapport['debiteurs'])->pluck('eleve_id');
            if ($request->boolean('en_regle')) {
                $query->whereNotIn('eleves.id', $debiteursIds);
            } else {
                $query->whereIn('eleves.id', $debiteursIds);
            }
        }

        switch ($request->input('tri', 'nom')) {
            case 'created_at':
                $query->orderByDesc('eleves.created_at');
                break;
            case 'statut':
                $query->orderBy('eleves.statut');
                break;
            case 'classe':
                $query->leftJoin('inscriptions', function ($j) use ($anneeId) {
                    $j->on('inscriptions.eleve_id', '=', 'eleves.id');
                    if ($anneeId) {
                        $j->where('inscriptions.annee_academique_id', $anneeId);
                    }
                })
                    ->leftJoin('classes', 'classes.id', '=', 'inscriptions.classe_id')
                    ->orderBy('classes.nom')
                    ->select('eleves.*');
                break;
            default:
                $query->orderBy('eleves.nom');
        }

        $eleves = $query->paginate(30);

        $montantParClasse = $anneeId
            ? FraisScolaire::where('annee_academique_id', $anneeId)
                ->select('classe_id', DB::raw('SUM(montant_total) as total'))
                ->groupBy('classe_id')
                ->pluck('total', 'classe_id')
            : collect();

        $eleves->getCollection()->transform(function ($eleve) use ($anneeId, $montantParClasse) {
            $inscription = Inscription::where('eleve_id', $eleve->id)
                ->when($anneeId, fn($q) => $q->where('annee_academique_id', $anneeId))
                ->with('classe')
                ->latest('id')
                ->first();

            $montantDu = $inscription ? ($montantParClasse[$inscription->classe_id] ?? 0) : 0;
            $montantPaye = $anneeId
                ? Paiement::where('eleve_id', $eleve->id)->where('annee_academique_id', $anneeId)->sum('montant')
                : 0;

            $eleve->classe_actuelle = $inscription?->classe;
            $eleve->dette = max(0, $montantDu - $montantPaye);

            return $eleve;
        });

        return response()->json($eleves);
    }

    // ════════════════════════════════════════════════════════════
    // 4. Créer un élève
    // ════════════════════════════════════════════════════════════
    public function store(Request $request)
    {
        $data = $request->validate([
            'nom'                  => 'required|string|max:100',
            'prenom'               => 'required|string|max:100',
            'sexe'                 => 'required|in:M,F',
            'date_naissance'       => 'nullable|date',
            'lieu_naissance'       => 'nullable|string|max:255',
            'nationalite'          => 'nullable|string|max:255',
            'telephone_parent'     => 'nullable|string|max:20',
            'classe_id'            => 'required|integer',
            'annee_academique_id'  => 'required|integer',
            'numero_appel'         => 'nullable|integer',
            'date_inscription'     => 'nullable|date',
            'statut'               => 'nullable|in:' . implode(',', self::STATUTS),
            'photo'                => 'nullable|image|mimes:jpg,jpeg,png|max:5120',
        ]);

        do {
            $matricule = strtoupper(Str::random(8));
        } while (Eleve::where('matricule', $matricule)->exists());

        $cheminPhoto = null;
        if ($request->hasFile('photo')) {
            $cheminPhoto = $request->file('photo')->store('eleves/photos', 'public');
        }

        $eleve = Eleve::create([
            'ecole_id'         => $request->user()->ecole_id,
            'nom'              => $data['nom'],
            'prenom'           => $data['prenom'],
            'sexe'             => $data['sexe'],
            'date_naissance'   => $data['date_naissance'] ?? null,
            'lieu_naissance'   => $data['lieu_naissance'] ?? null,
            'nationalite'      => $data['nationalite'] ?? 'Togolaise',
            'telephone_parent' => $data['telephone_parent'] ?? null,
            'matricule'        => $matricule,
            'numero_appel'     => $data['numero_appel'] ?? null,
            'date_inscription' => $data['date_inscription'] ?? now()->format('Y-m-d'),
            'statut'           => $data['statut'] ?? 'actif',
            'photo_path'       => $cheminPhoto,
        ]);

        Inscription::create([
            'eleve_id'            => $eleve->id,
            'classe_id'           => $data['classe_id'],
            'annee_academique_id' => $data['annee_academique_id'],
            'statut'              => 'inscrit',
        ]);

        $classe = Classe::find($data['classe_id']);

        ChronologieEleve::create([
            'eleve_id'    => $eleve->id,
            'type'        => 'inscription',
            'titre'       => 'Inscription',
            'description' => 'Inscrit(e) en ' . ($classe?->nom ?? 'classe'),
            'icone'       => 'school',
            'couleur'     => '#1E3A8A',
        ]);

        return response()->json([
            'message' => 'Élève créé et inscrit avec succès',
            'eleve'   => $eleve,
        ], 201);
    }

    // ════════════════════════════════════════════════════════════
    // 5. Fiche complète d'un élève
    // ════════════════════════════════════════════════════════════
    public function show(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;

        $eleve = Eleve::where('id', $id)
            ->where('ecole_id', $ecoleId)
            ->with([
                'parents',
                'documents',
                'inscriptions' => fn($q) => $q->orderByDesc('annee_academique_id'),
                'inscriptions.classe',
                'inscriptions.annee',
            ])
            ->firstOrFail();

        $inscriptionActuelle = $eleve->inscriptions->first();
        $classeActuelle = $inscriptionActuelle?->classe;
        $anneeActuelle = $inscriptionActuelle?->annee;

        $derniersPaiements = Paiement::where('eleve_id', $eleve->id)
            ->orderByDesc('date_paiement')
            ->limit(5)
            ->get();

        $detteActuelle = 0;
        if ($anneeActuelle && $classeActuelle) {
            $montantDu = FraisScolaire::where('classe_id', $classeActuelle->id)
                ->where('annee_academique_id', $anneeActuelle->id)
                ->sum('montant_total');
            $montantPaye = Paiement::where('eleve_id', $eleve->id)
                ->where('annee_academique_id', $anneeActuelle->id)
                ->sum('montant');
            $detteActuelle = max(0, $montantDu - $montantPaye);
        }

        $dernieresNotesParPeriode = collect();
        $moyenneGeneraleActuelle = null;
        $rangActuel = null;

        if ($anneeActuelle) {
            $periodes = PeriodeAcademique::where('annee_academique_id', $anneeActuelle->id)
                ->orderBy('ordre')
                ->get();

            $dernieresNotesParPeriode = $periodes->map(function ($p) use ($eleve) {
                $moyenne = Note::where('periode_id', $p->id)
                    ->where('eleve_id', $eleve->id)
                    ->where('statut', 'valide')
                    ->avg('valeur');

                return [
                    'periode_id' => $p->id,
                    'periode_nom' => $p->nom,
                    'moyenne'    => $moyenne !== null ? round($moyenne, 2) : null,
                ];
            });

            $periodeActive = $anneeActuelle->periodeActive();

            if ($periodeActive && $classeActuelle) {
                $classement = $this->calculerRangEleve($eleve->id, $classeActuelle, $periodeActive);
                $moyenneGeneraleActuelle = $classement['moyenne'];
                $rangActuel = $classement['rang'];
            }
        }

        $sanctions = Sanction::where('eleve_id', $eleve->id)
            ->orderByDesc('date_sanction')
            ->limit(5)
            ->get();

        $chronologie = ChronologieEleve::where('eleve_id', $eleve->id)
            ->orderByDesc('created_at')
            ->limit(30)
            ->get();

        $absencesTotal = Absence::where('eleve_id', $eleve->id)->count();
        $absencesJustifiees = Absence::where('eleve_id', $eleve->id)->where('justifiee', true)->count();

        return response()->json([
            'eleve'                => $eleve,
            'inscription_actuelle' => $inscriptionActuelle,
            'historique_inscriptions' => $eleve->inscriptions,
            'derniers_paiements'  => $derniersPaiements,
            'dette_actuelle'      => $detteActuelle,
            'notes_par_periode'   => $dernieresNotesParPeriode,
            'sanctions'           => $sanctions,
            'documents'           => $eleve->documents,
            'chronologie'         => $chronologie,
            'statistiques'        => [
                'nombre_absences_total'        => $absencesTotal,
                'nombre_absences_justifiees'   => $absencesJustifiees,
                'moyenne_generale_actuelle'    => $moyenneGeneraleActuelle,
                'rang_actuel'                  => $rangActuel,
            ],
        ]);
    }

    // Calcule la moyenne pondérée et le rang d'un élève dans sa classe pour
    // une période donnée (même logique que AnneeAcademiqueController).
    private function calculerRangEleve(int $eleveId, Classe $classe, PeriodeAcademique $periode): array
    {
        $coefficients = ClasseMatiere::where('classe_id', $classe->id)->get()->keyBy('matiere_id');

        $eleveIds = Inscription::where('classe_id', $classe->id)
            ->where('annee_academique_id', $periode->annee_academique_id)
            ->pluck('eleve_id');

        $moyennes = [];
        foreach ($eleveIds as $id) {
            $notes = Note::where('eleve_id', $id)
                ->where('periode_id', $periode->id)
                ->where('statut', 'valide')
                ->get()
                ->keyBy('matiere_id');

            $totalPoints = 0;
            $totalCoef = 0;
            foreach ($coefficients as $matiereId => $cm) {
                $note = $notes->get($matiereId);
                if ($note) {
                    $totalPoints += $note->valeur * $cm->coefficient;
                    $totalCoef += $cm->coefficient;
                }
            }

            if ($totalCoef > 0) {
                $moyennes[$id] = round($totalPoints / $totalCoef, 2);
            }
        }

        arsort($moyennes);
        $rang = null;
        $position = 0;
        foreach ($moyennes as $id => $m) {
            $position++;
            if ($id === $eleveId) {
                $rang = $position;
                break;
            }
        }

        return [
            'moyenne' => $moyennes[$eleveId] ?? null,
            'rang'    => $rang,
        ];
    }

    // ════════════════════════════════════════════════════════════
    // 6. Modifier un élève
    // ════════════════════════════════════════════════════════════
    public function update(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;
        $eleve = Eleve::where('id', $id)->where('ecole_id', $ecoleId)->firstOrFail();

        $data = $request->validate([
            'nom'                  => 'required|string|max:100',
            'prenom'               => 'required|string|max:100',
            'sexe'                 => 'required|in:M,F',
            'date_naissance'       => 'nullable|date',
            'lieu_naissance'       => 'nullable|string|max:255',
            'nationalite'          => 'nullable|string|max:255',
            'telephone_parent'     => 'nullable|string|max:20',
            'classe_id'            => 'nullable|integer',
            'annee_academique_id'  => 'nullable|integer',
            'numero_appel'         => 'nullable|integer',
            'date_inscription'     => 'nullable|date',
            'statut'               => 'nullable|in:' . implode(',', self::STATUTS),
            'photo'                => 'nullable|image|mimes:jpg,jpeg,png|max:5120',
        ]);

        if ($request->hasFile('photo')) {
            if ($eleve->photo_path) {
                Storage::disk('public')->delete($eleve->photo_path);
            }
            $data['photo_path'] = $request->file('photo')->store('eleves/photos', 'public');
        }

        $eleve->update(collect($data)->except(['classe_id', 'annee_academique_id', 'photo'])->toArray());

        if (!empty($data['classe_id']) && !empty($data['annee_academique_id'])) {
            Inscription::updateOrCreate(
                [
                    'eleve_id'            => $eleve->id,
                    'annee_academique_id' => $data['annee_academique_id'],
                ],
                ['classe_id' => $data['classe_id']]
            );
        }

        return response()->json([
            'message' => 'Élève mis à jour avec succès',
            'eleve'   => $eleve->fresh(),
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 7. Changer le statut d'un élève
    // ════════════════════════════════════════════════════════════
    public function changerStatut(Request $request, $id)
    {
        $request->validate([
            'statut' => 'required|in:' . implode(',', self::STATUTS),
            'motif'  => 'nullable|string|max:500',
        ]);

        $ecoleId = $request->user()->ecole_id;
        $eleve = Eleve::where('id', $id)->where('ecole_id', $ecoleId)->firstOrFail();

        $ancienStatut = $eleve->statut;
        $eleve->update(['statut' => $request->statut]);

        $typeChronologie = match ($request->statut) {
            'transfere' => 'transfert',
            'diplome'   => 'passage',
            default     => 'autre',
        };

        ChronologieEleve::create([
            'eleve_id'    => $eleve->id,
            'type'        => $typeChronologie,
            'titre'       => 'Changement de statut',
            'description' => "Statut changé de \"{$ancienStatut}\" à \"{$request->statut}\""
                . ($request->motif ? " — Motif : {$request->motif}" : ''),
            'icone'       => 'swap_horiz',
            'couleur'     => '#EA580C',
        ]);

        return response()->json([
            'message' => 'Statut mis à jour avec succès',
            'eleve'   => $eleve,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 8. Uploader la photo
    // ════════════════════════════════════════════════════════════
    public function uploaderPhoto(Request $request, $id)
    {
        $request->validate([
            'photo' => 'required|image|mimes:jpg,jpeg,png|max:5120',
        ]);

        $eleve = Eleve::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        if ($eleve->photo_path) {
            Storage::disk('public')->delete($eleve->photo_path);
        }

        $chemin = $request->file('photo')->store('eleves/photos', 'public');
        $eleve->update(['photo_path' => $chemin]);

        ChronologieEleve::create([
            'eleve_id'    => $eleve->id,
            'type'        => 'document_ajoute',
            'titre'       => 'Photo mise à jour',
            'icone'       => 'photo_camera',
            'couleur'     => '#0D9488',
        ]);

        return response()->json([
            'message'   => 'Photo mise à jour avec succès',
            'photo_url' => asset('storage/' . $chemin),
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 9. Gérer les parents (remplace la liste complète)
    // ════════════════════════════════════════════════════════════
    public function gererParents(Request $request, $id)
    {
        $request->validate([
            '*.nom'                    => 'required|string|max:255',
            '*.prenom'                 => 'nullable|string|max:255',
            '*.lien_parente'           => 'required|in:pere,mere,tuteur,autre',
            '*.telephone_principal'    => 'nullable|string|max:20',
            '*.telephone_secondaire'   => 'nullable|string|max:20',
            '*.adresse'                => 'nullable|string|max:255',
            '*.profession'             => 'nullable|string|max:255',
        ]);

        $eleve = Eleve::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        ParentEleve::where('eleve_id', $eleve->id)->delete();

        $parents = collect($request->all())->map(function ($p) use ($eleve) {
            return ParentEleve::create([
                'eleve_id'              => $eleve->id,
                'nom'                   => $p['nom'],
                'prenom'                => $p['prenom'] ?? null,
                'lien_parente'          => $p['lien_parente'],
                'telephone_principal'   => $p['telephone_principal'] ?? null,
                'telephone_secondaire'  => $p['telephone_secondaire'] ?? null,
                'adresse'               => $p['adresse'] ?? null,
                'profession'            => $p['profession'] ?? null,
            ]);
        });

        return response()->json([
            'message' => 'Parents mis à jour avec succès',
            'parents' => $parents,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 10. Uploader un document
    // ════════════════════════════════════════════════════════════
    public function uploaderDocument(Request $request, $id)
    {
        $request->validate([
            'nom'     => 'required|string|max:255',
            'type'    => 'required|in:acte_naissance,certificat_scolarite,photo,bulletin,certificat_transfert,autre',
            'fichier' => 'required|file|max:10240',
        ]);

        $eleve = Eleve::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $fichier = $request->file('fichier');
        $chemin = $fichier->store('eleves/documents', 'public');

        $document = DocumentEleve::create([
            'eleve_id'       => $eleve->id,
            'nom'            => $request->nom,
            'type'           => $request->type,
            'chemin_fichier' => $chemin,
            'taille'         => $fichier->getSize(),
        ]);

        ChronologieEleve::create([
            'eleve_id'    => $eleve->id,
            'type'        => 'document_ajoute',
            'titre'       => 'Document ajouté',
            'description' => $request->nom,
            'icone'       => 'description',
            'couleur'     => '#1E3A8A',
            'reference_id'   => $document->id,
            'reference_type' => 'DocumentEleve',
        ]);

        return response()->json([
            'message'  => 'Document ajouté avec succès',
            'document' => $document,
        ], 201);
    }

    // ════════════════════════════════════════════════════════════
    // 11. Supprimer un document
    // ════════════════════════════════════════════════════════════
    public function supprimerDocument(Request $request, $eleveId, $docId)
    {
        $eleve = Eleve::where('id', $eleveId)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $document = DocumentEleve::where('id', $docId)->where('eleve_id', $eleve->id)->firstOrFail();

        Storage::disk('public')->delete($document->chemin_fichier);
        $document->delete();

        return response()->json(['message' => 'Document supprimé avec succès']);
    }

    // ════════════════════════════════════════════════════════════
    // 12. Chronologie complète
    // ════════════════════════════════════════════════════════════
    public function chronologie(Request $request, $id)
    {
        $eleve = Eleve::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $chronologie = ChronologieEleve::where('eleve_id', $eleve->id)
            ->orderByDesc('created_at')
            ->get();

        return response()->json($chronologie);
    }

    // ════════════════════════════════════════════════════════════
    // 13. Export PDF
    // ════════════════════════════════════════════════════════════
    public function exporterPdf(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        $ecole = $request->user()->ecole;

        $query = Eleve::where('ecole_id', $ecoleId);

        if ($request->filled('classe_id')) {
            $query->whereHas('inscriptions', fn($q) => $q->where('classe_id', $request->classe_id));
        }
        if ($request->filled('statut')) {
            $query->where('statut', $request->statut);
        }

        $eleves = $query->with(['inscriptions' => fn($q) => $q->latest('id'), 'inscriptions.classe'])
            ->orderBy('nom')
            ->get();

        $pdf = Pdf::loadView('pdf.eleves_liste', [
            'ecole' => [
                'nom'              => $ecole->nom,
                'code_ecole'       => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'eleves'    => $eleves,
            'genere_le' => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download('liste_eleves.pdf');
    }

    // ════════════════════════════════════════════════════════════
    // 14. Export Excel (CSV)
    // ════════════════════════════════════════════════════════════
    public function exporterExcel(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $query = Eleve::where('ecole_id', $ecoleId);

        if ($request->filled('classe_id')) {
            $query->whereHas('inscriptions', fn($q) => $q->where('classe_id', $request->classe_id));
        }

        $eleves = $query->with(['inscriptions' => fn($q) => $q->latest('id'), 'inscriptions.classe'])
            ->orderBy('nom')
            ->get();

        $callback = function () use ($eleves) {
            $fichier = fopen('php://output', 'w');
            fwrite($fichier, "\xEF\xBB\xBF");
            fputcsv($fichier, [
                'Matricule', 'Nom', 'Prénom', 'Sexe', 'Date de naissance',
                'Lieu de naissance', 'Nationalité', 'Classe', 'Statut',
                'Téléphone parent', 'Date inscription',
            ]);

            foreach ($eleves as $e) {
                $classe = optional($e->inscriptions->first())->classe;
                fputcsv($fichier, [
                    $e->matricule,
                    $e->nom,
                    $e->prenom,
                    $e->sexe,
                    $e->date_naissance,
                    $e->lieu_naissance,
                    $e->nationalite,
                    $classe?->nom,
                    $e->statut,
                    $e->telephone_parent,
                    $e->date_inscription,
                ]);
            }

            fclose($fichier);
        };

        return response()->stream($callback, 200, [
            'Content-Type'        => 'text/csv',
            'Content-Disposition' => 'attachment; filename="eleves.csv"',
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 15. Élèves d'une classe
    // ════════════════════════════════════════════════════════════
    public function elevesParClasse(Request $request, $classeId)
    {
        $anneeId = $request->query('annee_id');

        $filtreInscription = function ($q) use ($classeId, $anneeId) {
            $q->where('classe_id', $classeId);
            if ($anneeId) {
                $q->where('annee_academique_id', $anneeId);
            }
        };

        $montantDuClasse = $anneeId
            ? FraisScolaire::where('classe_id', $classeId)->where('annee_academique_id', $anneeId)->sum('montant_total')
            : 0;

        $eleves = Eleve::where('ecole_id', $request->user()->ecole_id)
            ->whereHas('inscriptions', $filtreInscription)
            ->with(['inscriptions' => $filtreInscription])
            ->orderBy('nom')
            ->get()
            ->map(function ($eleve) use ($anneeId, $montantDuClasse, $classeId) {
                $eleve->inscription_statut = optional($eleve->inscriptions->first())->statut;
                unset($eleve->inscriptions);

                $montantPaye = $anneeId
                    ? Paiement::where('eleve_id', $eleve->id)->where('annee_academique_id', $anneeId)->sum('montant')
                    : 0;
                $eleve->dette = max(0, $montantDuClasse - $montantPaye);

                $eleve->derniere_absence = Absence::where('eleve_id', $eleve->id)
                    ->where('classe_id', $classeId)
                    ->orderByDesc('date_absence')
                    ->value('date_absence');

                return $eleve;
            });

        return response()->json($eleves);
    }
}
