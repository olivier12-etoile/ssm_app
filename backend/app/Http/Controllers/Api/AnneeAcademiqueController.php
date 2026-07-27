<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\Absence;
use App\Models\Classe;
use App\Models\HistoriqueAnnee;
use App\Models\Inscription;
use App\Models\Note;
use App\Models\Paiement;
use App\Models\PeriodeAcademique;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AnneeAcademiqueController extends Controller
{
    private const NIVEAUX_PAR_CYCLE = [
        'college'          => ['6ème', '5ème', '4ème', '3ème'],
        'lycee_moderne'    => ['Seconde', 'Première', 'Terminale'],
        'lycee_technique'  => ['Seconde', 'Première', 'Terminale'],
    ];

    // ── 1. Liste des années de l'école ──────────────────────────
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $annees = AnneeAcademique::where('ecole_id', $ecoleId)
            ->with(['periodes' => fn($q) => $q->orderBy('date_debut')])
            ->orderByDesc('date_debut')
            ->get();

        $annees->each(function ($annee) {
            $annee->nombre_eleves = Inscription::where('annee_academique_id', $annee->id)->count();
            $annee->nombre_classes = Classe::where('annee_academique_id', $annee->id)->count();
            $annee->nombre_enseignants = DB::table('enseignant_classe_matiere')
                ->join('classes', 'classes.id', '=', 'enseignant_classe_matiere.classe_id')
                ->where('classes.annee_academique_id', $annee->id)
                ->distinct()
                ->count('enseignant_classe_matiere.enseignant_id');

            $periodeActive = $annee->periodes->firstWhere('statut', 'ouvert');
            $annee->periode_active = $periodeActive;
            $annee->jours_restants_periode = $periodeActive
                ? $this->joursRestants($periodeActive->date_fin)
                : null;
        });

        return response()->json($annees);
    }

    // ── 2. Année active de l'école ───────────────────────────────
    public function anneeActive(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $annee = AnneeAcademique::where('ecole_id', $ecoleId)
            ->where('statut', 'active')
            ->with(['periodes' => fn($q) => $q->orderBy('date_debut')])
            ->first();

        if (!$annee) {
            return response()->json([
                'message' => "Aucune année académique active pour le moment.",
                'annee'   => null,
            ], 404);
        }

        $periodeActive = $annee->periodes->firstWhere('statut', 'ouvert');
        $joursRestants = $periodeActive ? $this->joursRestants($periodeActive->date_fin) : null;

        $alertes = [];
        if ($periodeActive && $joursRestants !== null && $joursRestants <= 7) {
            $alertes[] = [
                'type'           => 'fin_periode_proche',
                'message'        => "La période \"{$periodeActive->nom}\" se termine dans {$joursRestants} jour(s).",
                'jours_restants' => $joursRestants,
            ];
        }

        return response()->json([
            'annee'                  => $annee,
            'periode_active'         => $periodeActive,
            'jours_restants_periode' => $joursRestants,
            'alertes'                => $alertes,
        ]);
    }

    // ── 3. Créer une année académique ────────────────────────────
    public function store(Request $request)
    {
        $request->validate([
            'libelle'    => 'required|string|max:20',
            'date_debut' => 'required|date',
            'date_fin'   => 'required|date|after:date_debut',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $existe = AnneeAcademique::where('ecole_id', $ecoleId)
            ->where('libelle', $request->libelle)
            ->exists();

        if ($existe) {
            return response()->json([
                'message' => "Une année académique \"{$request->libelle}\" existe déjà.",
            ], 409);
        }

        $annee = AnneeAcademique::create([
            'ecole_id'   => $ecoleId,
            'libelle'    => $request->libelle,
            'date_debut' => $request->date_debut,
            'date_fin'   => $request->date_fin,
            'statut'     => 'en_preparation',
            'cree_par'   => $request->user()->id,
        ]);

        HistoriqueAnnee::create([
            'annee_id' => $annee->id,
            'action'   => 'creation',
            'fait_par' => $request->user()->id,
        ]);

        return response()->json([
            'message' => 'Année académique créée avec succès',
            'annee'   => $annee,
        ], 201);
    }

    // ── 4. Activer une année académique ──────────────────────────
    public function activer(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;
        $annee = AnneeAcademique::where('id', $id)->where('ecole_id', $ecoleId)->firstOrFail();

        $dejaActive = AnneeAcademique::where('ecole_id', $ecoleId)
            ->where('statut', 'active')
            ->where('id', '!=', $annee->id)
            ->first();

        if ($dejaActive) {
            return response()->json([
                'message' => "L'année \"{$dejaActive->libelle}\" est déjà active. Clôturez-la avant d'en activer une autre.",
            ], 409);
        }

        $annee->update([
            'statut'     => 'active',
            'active_par' => $request->user()->id,
            'active_le'  => now(),
        ]);

        HistoriqueAnnee::create([
            'annee_id' => $annee->id,
            'action'   => 'activation',
            'fait_par' => $request->user()->id,
        ]);

        return response()->json([
            'message' => 'Année académique activée avec succès',
            'annee'   => $annee,
        ]);
    }

    // ── 5. Clôturer une année académique ─────────────────────────
    public function cloturer(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;
        $annee = AnneeAcademique::where('id', $id)->where('ecole_id', $ecoleId)->firstOrFail();

        $annee->update([
            'statut'      => 'cloturee',
            'cloture_par' => $request->user()->id,
            'cloture_le'  => now(),
        ]);

        PeriodeAcademique::where('annee_academique_id', $annee->id)
            ->where('statut', 'ouvert')
            ->update([
                'statut'      => 'ferme',
                'fermee_par'  => $request->user()->id,
                'fermee_le'   => now(),
            ]);

        HistoriqueAnnee::create([
            'annee_id' => $annee->id,
            'action'   => 'cloture',
            'fait_par' => $request->user()->id,
        ]);

        return response()->json([
            'message' => 'Année académique clôturée avec succès',
            'annee'   => $annee,
        ]);
    }

    // ── 6. Archiver une année académique ─────────────────────────
    public function archiver(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;
        $annee = AnneeAcademique::where('id', $id)->where('ecole_id', $ecoleId)->firstOrFail();

        if ($annee->statut !== 'cloturee') {
            return response()->json([
                'message' => "Seule une année académique clôturée peut être archivée.",
            ], 409);
        }

        $annee->update(['statut' => 'archivee']);

        HistoriqueAnnee::create([
            'annee_id' => $annee->id,
            'action'   => 'archivage',
            'fait_par' => $request->user()->id,
        ]);

        return response()->json([
            'message' => 'Année académique archivée avec succès',
            'annee'   => $annee,
        ]);
    }

    // ── 7. Passage des élèves vers l'année suivante ──────────────
    public function passerEleves(Request $request, $id)
    {
        $request->validate([
            'passer_automatique' => 'required|boolean',
            'redoublants'        => 'nullable|array',
            'redoublants.*'      => 'integer',
            'diplomes'           => 'nullable|array',
            'diplomes.*'         => 'integer',
        ]);

        $ecoleId = $request->user()->ecole_id;
        $annee = AnneeAcademique::where('id', $id)->where('ecole_id', $ecoleId)->firstOrFail();

        $nouvelleAnnee = AnneeAcademique::where('ecole_id', $ecoleId)
            ->where('date_debut', '>', $annee->date_debut)
            ->orderBy('date_debut')
            ->first();

        if (!$nouvelleAnnee) {
            return response()->json([
                'message' => "Aucune année académique suivante n'a été créée. Créez-la avant de lancer le passage des élèves.",
            ], 409);
        }

        $redoublants        = collect($request->input('redoublants', []));
        $diplomes           = collect($request->input('diplomes', []));
        $passerAutomatique  = $request->boolean('passer_automatique');

        $inscriptions = Inscription::where('annee_academique_id', $annee->id)
            ->with('classe')
            ->get();

        $resultats = [
            'admis'        => 0,
            'redoublants'  => 0,
            'diplomes'     => 0,
            'non_traites'  => 0,
            'non_places'   => 0,
        ];

        foreach ($inscriptions as $inscription) {
            $eleveId = $inscription->eleve_id;

            if ($diplomes->contains($eleveId)) {
                $inscription->update(['statut' => 'diplome']);
                $resultats['diplomes']++;
                continue;
            }

            if ($redoublants->contains($eleveId)) {
                $inscription->update(['statut' => 'redoublant']);
                $resultats['redoublants']++;
                continue;
            }

            if (!$passerAutomatique) {
                $resultats['non_traites']++;
                continue;
            }

            $moyenne = Note::whereHas('periode', fn($q) => $q->where('annee_academique_id', $annee->id))
                ->where('eleve_id', $eleveId)
                ->where('statut', 'valide')
                ->avg('valeur');

            if ($moyenne !== null && $moyenne >= (float) $annee->regle_passage_moyenne) {
                $inscription->update(['statut' => 'admis']);
                $resultats['admis']++;

                if (!$this->inscrireClasseSuperieure($inscription, $nouvelleAnnee)) {
                    $resultats['non_places']++;
                }
            } else {
                $inscription->update(['statut' => 'redoublant']);
                $resultats['redoublants']++;
            }
        }

        HistoriqueAnnee::create([
            'annee_id' => $annee->id,
            'action'   => 'passage_eleves',
            'fait_par' => $request->user()->id,
            'details'  => json_encode([
                'nouvelle_annee_id'      => $nouvelleAnnee->id,
                'nouvelle_annee_libelle' => $nouvelleAnnee->libelle,
                'resultats'              => $resultats,
            ]),
        ]);

        return response()->json([
            'message'        => 'Passage des élèves effectué avec succès',
            'nouvelle_annee' => [
                'id'      => $nouvelleAnnee->id,
                'libelle' => $nouvelleAnnee->libelle,
            ],
            'resultats' => $resultats,
        ]);
    }

    // ── 8. Statistiques d'une année académique ───────────────────
    public function statistiques(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;
        $annee = AnneeAcademique::where('id', $id)->where('ecole_id', $ecoleId)->firstOrFail();

        $inscriptions = Inscription::where('annee_academique_id', $annee->id)->with('eleve')->get();
        $garcons = $inscriptions->filter(fn($i) => $i->eleve?->sexe === 'M')->count();
        $filles  = $inscriptions->filter(fn($i) => $i->eleve?->sexe === 'F')->count();

        $nombreClasses = Classe::where('annee_academique_id', $annee->id)->count();

        $nombreEnseignants = DB::table('enseignant_classe_matiere')
            ->join('classes', 'classes.id', '=', 'enseignant_classe_matiere.classe_id')
            ->where('classes.annee_academique_id', $annee->id)
            ->distinct()
            ->count('enseignant_classe_matiere.enseignant_id');

        $moyennesParEleve = Note::whereHas('periode', fn($q) => $q->where('annee_academique_id', $annee->id))
            ->where('statut', 'valide')
            ->select('eleve_id', DB::raw('AVG(valeur) as moyenne'))
            ->groupBy('eleve_id')
            ->pluck('moyenne', 'eleve_id');

        $tauxReussite = $moyennesParEleve->isEmpty()
            ? 0
            : round($moyennesParEleve->filter(fn($m) => $m >= 10)->count() / $moyennesParEleve->count() * 100, 1);
        $tauxEchec = $moyennesParEleve->isEmpty() ? 0 : round(100 - $tauxReussite, 1);

        $totalPaiements = Paiement::where('annee_academique_id', $annee->id)->sum('montant');

        $absencesTotal = Absence::whereHas('classe', fn($q) => $q->where('annee_academique_id', $annee->id))->count();

        return response()->json([
            'annee_id'           => $annee->id,
            'annee_libelle'      => $annee->libelle,
            'nombre_eleves'      => $inscriptions->count(),
            'garcons'            => $garcons,
            'filles'             => $filles,
            'nombre_classes'     => $nombreClasses,
            'nombre_enseignants' => $nombreEnseignants,
            'taux_reussite'      => $tauxReussite,
            'taux_echec'         => $tauxEchec,
            'total_paiements'    => $totalPaiements,
            'absences_total'     => $absencesTotal,
        ]);
    }

    // ── 9. Historique des actions sur les années de l'école ───────
    public function historique(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $historique = HistoriqueAnnee::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->with(['annee:id,libelle', 'utilisateur:id,name'])
            ->orderByDesc('created_at')
            ->limit(100)
            ->get()
            ->map(fn($h) => [
                'id'              => $h->id,
                'action'          => $h->action,
                'annee_id'        => $h->annee_id,
                'annee_libelle'   => $h->annee?->libelle,
                'utilisateur_nom' => $h->utilisateur?->name,
                'details'         => $h->details,
                'created_at'      => $h->created_at,
            ]);

        return response()->json($historique);
    }

    // ── 10. Aperçu du passage des élèves (lecture seule) ───────────
    public function apercuPassage(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;
        $annee = AnneeAcademique::where('id', $id)->where('ecole_id', $ecoleId)->firstOrFail();

        $inscriptions = Inscription::where('annee_academique_id', $annee->id)
            ->with(['eleve', 'classe'])
            ->get();

        $eleves = $inscriptions->map(function ($inscription) use ($annee) {
            $moyenne = Note::whereHas('periode', fn($q) => $q->where('annee_academique_id', $annee->id))
                ->where('eleve_id', $inscription->eleve_id)
                ->where('statut', 'valide')
                ->avg('valeur');

            $niveau = $inscription->classe?->niveau;
            $admis  = $moyenne !== null && $moyenne >= (float) $annee->regle_passage_moyenne;

            return [
                'eleve_id'      => $inscription->eleve_id,
                'nom'           => $inscription->eleve?->nom,
                'prenom'        => $inscription->eleve?->prenom,
                'classe_id'     => $inscription->classe_id,
                'classe_nom'    => $inscription->classe?->nom,
                'niveau'        => $niveau,
                'est_terminale' => $niveau === 'Terminale',
                'moyenne'       => $moyenne !== null ? round($moyenne, 2) : null,
                'verdict'       => $moyenne === null ? 'sans_note' : ($admis ? 'admis' : 'redoublant'),
            ];
        })->values();

        return response()->json([
            'annee_id'              => $annee->id,
            'regle_passage_moyenne' => (float) $annee->regle_passage_moyenne,
            'eleves'                => $eleves,
        ]);
    }

    // ── Aides internes ────────────────────────────────────────────

    private function joursRestants(string $dateFin): int
    {
        $fin = strtotime($dateFin . ' 00:00:00');
        $aujourdhui = strtotime(now()->format('Y-m-d') . ' 00:00:00');

        return (int) round(($fin - $aujourdhui) / 86400);
    }

    private function niveauSuivant(?string $cycle, ?string $niveau): ?string
    {
        $liste = self::NIVEAUX_PAR_CYCLE[$cycle] ?? null;
        if (!$liste || !$niveau) {
            return null;
        }

        $index = array_search($niveau, $liste, true);
        if ($index === false || $index + 1 >= count($liste)) {
            return null;
        }

        return $liste[$index + 1];
    }

    private function inscrireClasseSuperieure(Inscription $inscription, AnneeAcademique $nouvelleAnnee): bool
    {
        $classeActuelle = $inscription->classe;
        if (!$classeActuelle) {
            return false;
        }

        $niveauCible = $this->niveauSuivant($classeActuelle->cycle, $classeActuelle->niveau);
        if (!$niveauCible) {
            return false;
        }

        $requete = Classe::where('annee_academique_id', $nouvelleAnnee->id)
            ->where('ecole_id', $classeActuelle->ecole_id)
            ->where('cycle', $classeActuelle->cycle)
            ->where('niveau', $niveauCible);

        if ($classeActuelle->serie) {
            $requete->where('serie', $classeActuelle->serie);
        }

        $classeCible = (clone $requete)->where('indice', $classeActuelle->indice)->first()
            ?? $requete->first();

        if (!$classeCible) {
            return false;
        }

        Inscription::updateOrCreate(
            [
                'eleve_id'             => $inscription->eleve_id,
                'annee_academique_id'  => $nouvelleAnnee->id,
            ],
            [
                'classe_id' => $classeCible->id,
                'statut'    => 'inscrit',
            ]
        );

        return true;
    }
}