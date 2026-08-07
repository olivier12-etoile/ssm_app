<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\Absence;
use App\Models\Classe;
use App\Models\ClasseMatiere;
use App\Models\Evaluation;
use App\Models\HistoriqueAnnee;
use App\Models\Inscription;
use App\Models\JournalAction;
use App\Models\Note;
use App\Models\Paiement;
use App\Models\PeriodeAcademique;
use Barryvdh\DomPDF\Facade\Pdf;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AnneeAcademiqueController extends Controller
{
    private const NIVEAUX_PAR_CYCLE = [
        'college'          => ['6ème', '5ème', '4ème', '3ème'],
        'lycee_moderne'    => ['Seconde', 'Première', 'Terminale'],
        'lycee_technique'  => ['Seconde', 'Première', 'Terminale'],
    ];

    private const CYCLES_LYCEE = ['lycee_moderne', 'lycee_technique'];

    private const DEFINITIONS_PERIODES = [
        'trimestres' => [
            ['nom' => '1er Trimestre', 'code' => 'T1', 'couleur' => '#1E3A8A'],
            ['nom' => '2ème Trimestre', 'code' => 'T2', 'couleur' => '#0D9488'],
            ['nom' => '3ème Trimestre', 'code' => 'T3', 'couleur' => '#D97706'],
        ],
        'semestres' => [
            ['nom' => 'Semestre 1', 'code' => 'S1', 'couleur' => '#1E3A8A'],
            ['nom' => 'Semestre 2', 'code' => 'S2', 'couleur' => '#0D9488'],
        ],
    ];

    // ════════════════════════════════════════════════════════════
    // 1. Tableau de bord
    // ════════════════════════════════════════════════════════════
    public function tableauDeBord(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $annee = AnneeAcademique::where('ecole_id', $ecoleId)
            ->where('statut', 'active')
            ->with(['periodes', 'creePar', 'activePar', 'cloturePar'])
            ->first();

        if (!$annee) {
            return response()->json([
                'annee_active'           => null,
                'periode_active'         => null,
                'jours_restants_periode' => null,
                'progression_barre'      => null,
                'classes_notes_terminees'=> 0,
                'total_classes'          => 0,
                'bulletins_generes'      => 0,
                'total_eleves'           => 0,
                'alertes'                => [[
                    'type'     => 'critique',
                    'message'  => "Aucune année académique active. Créez ou activez une année pour commencer.",
                ]],
                'enseignants_en_retard'  => [],
            ]);
        }

        $periodeActive = $annee->periodeActive();
        $joursRestants = $annee->joursRestantsPeriode();
        $progressionBarre = $periodeActive ? $periodeActive->progressionJours() : null;

        $classes = Classe::where('annee_academique_id', $annee->id)->get();
        $totalClasses = $classes->count();

        $etatEnseignants = $periodeActive ? $periodeActive->etatEnseignants() : collect();
        $enseignantsEnRetard = $etatEnseignants->where('statut', '!=', 'termine')->values();

        // Une classe est "terminée" si toutes les affectations de cette classe
        // pour la période active sont à 100%.
        $classesNoteesTerminees = 0;
        if ($periodeActive) {
            $parClasse = $etatEnseignants->groupBy('classe_id');
            foreach ($parClasse as $lignes) {
                if ($lignes->every(fn($l) => $l['statut'] === 'termine')) {
                    $classesNoteesTerminees++;
                }
            }
        }

        $totalEleves = Inscription::where('annee_academique_id', $annee->id)->count();

        // Aucune table de bulletins n'existe : on estime le nombre de
        // bulletins "prêts" par le nombre d'élèves ayant au moins une note
        // validée sur la période active.
        $bulletinsGeneres = $periodeActive
            ? Note::where('periode_id', $periodeActive->id)
                ->where('statut', 'valide')
                ->distinct('eleve_id')
                ->count('eleve_id')
            : 0;

        $alertes = [];

        if (!$periodeActive) {
            $alertes[] = [
                'type'    => 'avertissement',
                'message' => "Aucune période n'est actuellement ouverte pour cette année.",
            ];
        } elseif ($joursRestants !== null && $joursRestants <= 7) {
            $alertes[] = [
                'type'           => $joursRestants < 0 ? 'critique' : 'avertissement',
                'message'        => $joursRestants < 0
                    ? "La période \"{$periodeActive->nom}\" est dépassée de " . abs($joursRestants) . " jour(s)."
                    : "La période \"{$periodeActive->nom}\" se termine dans {$joursRestants} jour(s).",
                'jours_restants' => $joursRestants,
            ];
        }

        if ($enseignantsEnRetard->isNotEmpty()) {
            $alertes[] = [
                'type'    => 'info',
                'message' => $enseignantsEnRetard->count() . " affectation(s) enseignant n'ont pas encore de notes complètes.",
            ];
        }

        return response()->json([
            'annee_active'            => $annee,
            'periode_active'          => $periodeActive,
            'jours_restants_periode'  => $joursRestants,
            'progression_barre'       => $progressionBarre,
            'classes_notes_terminees' => $classesNoteesTerminees,
            'total_classes'           => $totalClasses,
            'bulletins_generes'       => $bulletinsGeneres,
            'total_eleves'            => $totalEleves,
            'alertes'                 => $alertes,
            'enseignants_en_retard'   => $enseignantsEnRetard,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 2. Liste des années de l'école
    // ════════════════════════════════════════════════════════════
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $annees = AnneeAcademique::where('ecole_id', $ecoleId)
            ->with(['periodes' => fn($q) => $q->orderBy('ordre')])
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

            $periodeActive = $annee->periodeActive();
            $annee->periode_active = $periodeActive;
            $annee->jours_restants_periode = $annee->joursRestantsPeriode();
        });

        return response()->json($annees);
    }

    // ── (legacy) Année active de l'école — conservé pour compatibilité ──
    public function anneeActive(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $annee = AnneeAcademique::where('ecole_id', $ecoleId)
            ->where('statut', 'active')
            ->with(['periodes' => fn($q) => $q->orderBy('ordre')])
            ->first();

        if (!$annee) {
            return response()->json([
                'message' => "Aucune année académique active pour le moment.",
                'annee'   => null,
            ], 404);
        }

        $periodeActive = $annee->periodeActive();
        $joursRestants = $annee->joursRestantsPeriode();

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

    // ════════════════════════════════════════════════════════════
    // 3. Créer une année académique
    // ════════════════════════════════════════════════════════════
    public function store(Request $request)
    {
        $request->validate([
            'libelle'       => 'required|string|max:20',
            'date_debut'    => 'required|date',
            'date_fin'      => 'required|date|after:date_debut',
            'type_periodes' => 'nullable|in:trimestres,semestres,auto',
            'regle_passage_moyenne' => 'nullable|numeric|min:0|max:20',
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

        $typeDemande = $request->type_periodes ?? 'auto';

        if ($typeDemande === 'auto') {
            $typePeriodes = $this->detecterTypePeriodes($ecoleId);
            if ($typePeriodes === null) {
                return response()->json([
                    'message' => "L'école a à la fois des classes de collège/primaire et de lycée. Choisissez manuellement 'trimestres' ou 'semestres'.",
                ], 422);
            }
        } else {
            $typePeriodes = $typeDemande;
        }

        $annee = AnneeAcademique::create([
            'ecole_id'               => $ecoleId,
            'libelle'                => $request->libelle,
            'date_debut'             => $request->date_debut,
            'date_fin'               => $request->date_fin,
            'statut'                 => 'en_preparation',
            'cree_par'               => $request->user()->id,
            'type_periodes'          => $typePeriodes,
            'regle_passage_moyenne'  => $request->regle_passage_moyenne ?? 10.00,
        ]);

        $this->creerPeriodesAutomatiques($annee, $typePeriodes);

        JournalAction::enregistrer('AnneeAcademique', $annee->id, 'creation', $request->user()->id, $ecoleId, [
            'libelle'       => $annee->libelle,
            'type_periodes' => $typePeriodes,
        ]);

        return response()->json([
            'message' => 'Année académique créée avec succès',
            'annee'   => $annee->load('periodes'),
        ], 201);
    }

    // Détermine automatiquement trimestres/semestres selon les cycles des
    // classes de l'école. Retourne null si les deux cycles coexistent
    // (le directeur doit alors choisir manuellement).
    private function detecterTypePeriodes(int $ecoleId): ?string
    {
        $cycles = Classe::where('ecole_id', $ecoleId)->pluck('cycle')->unique();

        $aLycee  = $cycles->intersect(self::CYCLES_LYCEE)->isNotEmpty();
        $aCollege = $cycles->contains('college');

        if ($aLycee && $aCollege) {
            return null;
        }

        return $aLycee ? 'semestres' : 'trimestres';
    }

    // Répartit les dates de l'année entre les périodes du type choisi,
    // à parts égales (la dernière période récupère les jours restants).
    private function creerPeriodesAutomatiques(AnneeAcademique $annee, string $typePeriodes): void
    {
        $definitions = self::DEFINITIONS_PERIODES[$typePeriodes] ?? self::DEFINITIONS_PERIODES['trimestres'];

        $debut = Carbon::parse($annee->date_debut);
        $fin   = Carbon::parse($annee->date_fin);
        $totalJours = $debut->diffInDays($fin);
        $nombre = count($definitions);
        $joursParPeriode = intdiv($totalJours, $nombre);

        $curseur = $debut->copy();
        foreach ($definitions as $index => $def) {
            $estDerniere = $index === $nombre - 1;
            $finPeriode = $estDerniere ? $fin->copy() : $curseur->copy()->addDays($joursParPeriode);

            PeriodeAcademique::create([
                'annee_academique_id' => $annee->id,
                'nom'                 => $def['nom'],
                'code'                => $def['code'],
                'couleur'             => $def['couleur'],
                'ordre'               => $index + 1,
                'date_debut'          => $curseur->format('Y-m-d'),
                'date_fin'            => $finPeriode->format('Y-m-d'),
                'statut'              => 'preparation',
            ]);

            $curseur = $finPeriode->copy()->addDay();
        }
    }

    // ════════════════════════════════════════════════════════════
    // 4. Activer une année académique
    // ════════════════════════════════════════════════════════════
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

        JournalAction::enregistrer('AnneeAcademique', $annee->id, 'activation', $request->user()->id, $ecoleId, [
            'libelle' => $annee->libelle,
        ]);

        return response()->json([
            'message' => 'Année académique activée avec succès',
            'annee'   => $annee,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 5. Clôturer une année académique
    // ════════════════════════════════════════════════════════════
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
            ->whereIn('statut', ['ouverte', 'en_veille'])
            ->update([
                'statut'     => 'cloturee',
                'fermee_par' => $request->user()->id,
                'fermee_le'  => now(),
            ]);

        JournalAction::enregistrer('AnneeAcademique', $annee->id, 'cloture', $request->user()->id, $ecoleId, [
            'libelle' => $annee->libelle,
        ]);

        return response()->json([
            'message' => 'Année académique clôturée avec succès',
            'annee'   => $annee,
        ]);
    }

    // ── (legacy) Archiver une année académique — conservé, non listé
    //    explicitement dans le nouveau cahier des charges mais toujours
    //    utilisé par l'écran de gestion des années. ──
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

        JournalAction::enregistrer('AnneeAcademique', $annee->id, 'archivage', $request->user()->id, $ecoleId, [
            'libelle' => $annee->libelle,
        ]);

        return response()->json([
            'message' => 'Année académique archivée avec succès',
            'annee'   => $annee,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 6. Passage des élèves vers l'année suivante
    // ════════════════════════════════════════════════════════════
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
            'passes'       => 0,
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
                $resultats['passes']++;

                if (!$this->inscrireClasseSuperieure($inscription, $nouvelleAnnee)) {
                    $resultats['non_places']++;
                }
            } else {
                $inscription->update(['statut' => 'redoublant']);
                $resultats['redoublants']++;
            }
        }

        JournalAction::enregistrer('AnneeAcademique', $annee->id, 'passage_eleves', $request->user()->id, $ecoleId, [
            'nouvelle_annee_id'      => $nouvelleAnnee->id,
            'nouvelle_annee_libelle' => $nouvelleAnnee->libelle,
            'passes'                 => $resultats['passes'],
            'redoublants'            => $resultats['redoublants'],
            'diplomes'               => $resultats['diplomes'],
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

    // ── (legacy) Statistiques d'une année académique ──
    public function statistiques(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;
        $annee = AnneeAcademique::where('id', $id)->where('ecole_id', $ecoleId)->firstOrFail();

        return response()->json($this->calculerStatistiquesAnnee($annee));
    }

    private function calculerStatistiquesAnnee(AnneeAcademique $annee): array
    {
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

        return [
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
        ];
    }

    // ════════════════════════════════════════════════════════════
    // 7. Détails complets d'une année (fiche année)
    // ════════════════════════════════════════════════════════════
    public function details(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;
        $annee = AnneeAcademique::where('id', $id)->where('ecole_id', $ecoleId)->firstOrFail();

        $stats = $this->calculerStatistiquesAnnee($annee);

        $periodes = PeriodeAcademique::where('annee_academique_id', $annee->id)
            ->orderBy('ordre')
            ->get()
            ->map(fn($p) => [
                'id'                => $p->id,
                'nom'               => $p->nom,
                'code'              => $p->code,
                'couleur'           => $p->couleur,
                'date_debut'        => $p->date_debut,
                'date_fin'          => $p->date_fin,
                'statut'            => $p->statut,
                'notes_saisies'     => Note::where('periode_id', $p->id)->count(),
                'bulletins_generes' => Note::where('periode_id', $p->id)->where('statut', 'valide')->distinct('eleve_id')->count('eleve_id'),
            ]);

        $classes = Classe::where('annee_academique_id', $annee->id)
            ->orderBy('nom')
            ->get()
            ->map(function ($c) use ($annee) {
                $nombreEleves = Inscription::where('classe_id', $c->id)->count();

                $moyennes = Note::whereHas('periode', fn($q) => $q->where('annee_academique_id', $annee->id))
                    ->where('statut', 'valide')
                    ->whereHas('eleve.inscriptions', fn($q) => $q->where('classe_id', $c->id)->where('annee_academique_id', $annee->id))
                    ->select('eleve_id', DB::raw('AVG(valeur) as moyenne'))
                    ->groupBy('eleve_id')
                    ->pluck('moyenne');

                return [
                    'id'             => $c->id,
                    'nom'            => $c->nom,
                    'nombre_eleves'  => $nombreEleves,
                    'moyenne'        => $moyennes->isEmpty() ? null : round($moyennes->avg(), 2),
                    'taux_reussite'  => $moyennes->isEmpty()
                        ? 0
                        : round($moyennes->filter(fn($m) => $m >= 10)->count() / $moyennes->count() * 100, 1),
                ];
            });

        $eleves = Inscription::where('annee_academique_id', $annee->id)
            ->with(['eleve', 'classe'])
            ->get()
            ->map(function ($i) use ($annee) {
                $moyenne = Note::whereHas('periode', fn($q) => $q->where('annee_academique_id', $annee->id))
                    ->where('eleve_id', $i->eleve_id)
                    ->where('statut', 'valide')
                    ->avg('valeur');

                return [
                    'eleve_id'   => $i->eleve_id,
                    'nom'        => $i->eleve?->nom,
                    'prenom'     => $i->eleve?->prenom,
                    'photo_url'  => $i->eleve?->photo_url,
                    'classe_nom' => $i->classe?->nom,
                    'moyenne'    => $moyenne !== null ? round($moyenne, 2) : null,
                    'statut'     => $i->statut,
                ];
            })
            ->values();

        $affectations = DB::table('enseignant_classe_matiere')
            ->join('classes', 'classes.id', '=', 'enseignant_classe_matiere.classe_id')
            ->join('matieres', 'matieres.id', '=', 'enseignant_classe_matiere.matiere_id')
            ->join('users', 'users.id', '=', 'enseignant_classe_matiere.enseignant_id')
            ->where('classes.annee_academique_id', $annee->id)
            ->select(
                'users.id as enseignant_id',
                'users.name',
                'users.fonction',
                'users.photo_path',
                'classes.nom as classe_nom',
                'matieres.nom as matiere_nom'
            )
            ->get();

        $enseignants = $affectations->groupBy('enseignant_id')->map(function ($lignes, $enseignantId) use ($annee) {
            $premiere = $lignes->first();

            return [
                'enseignant_id'      => $enseignantId,
                'nom'                => $premiere->name,
                'fonction'           => $premiere->fonction,
                'photo_url'          => $premiere->photo_path ? asset('storage/' . $premiere->photo_path) : null,
                'classes'            => $lignes->map(fn($l) => [
                    'classe_nom'  => $l->classe_nom,
                    'matiere_nom' => $l->matiere_nom,
                ])->values(),
                'notes_saisies'      => Note::where('enseignant_id', $enseignantId)
                    ->whereHas('periode', fn($q) => $q->where('annee_academique_id', $annee->id))
                    ->count(),
                'evaluations_creees' => Evaluation::where('enseignant_id', $enseignantId)
                    ->whereHas('periode', fn($q) => $q->where('annee_academique_id', $annee->id))
                    ->count(),
            ];
        })->values();

        $rapport = (new FraisScolaireController())->calculerRapportFinancier($ecoleId, $annee->id, null);

        $historiqueComplet = JournalAction::where('ecole_id', $ecoleId)
            ->where(function ($q) use ($annee) {
                $q->where(function ($q2) use ($annee) {
                    $q2->where('entite_type', 'AnneeAcademique')->where('entite_id', $annee->id);
                })->orWhere(function ($q2) use ($annee) {
                    $q2->where('entite_type', 'Periode')
                        ->whereIn('entite_id', $annee->periodes()->pluck('id'));
                });
            })
            ->with('auteur:id,name')
            ->orderByDesc('created_at')
            ->get()
            ->map(fn($h) => [
                'action'          => $h->action,
                'entite_type'     => $h->entite_type,
                'utilisateur_nom' => $h->auteur?->name,
                'details'         => $h->details,
                'created_at'      => $h->created_at,
            ]);

        return response()->json([
            'annee'       => $annee,
            'stats'       => $stats,
            'periodes'    => $periodes,
            'classes'     => $classes,
            'eleves'      => $eleves,
            'enseignants' => $enseignants,
            'finances'    => [
                'total_attendu'  => $rapport['total_global']['total_attendu'],
                'total_encaisse' => $rapport['total_global']['total_encaisse'],
                'total_restant'  => $rapport['total_global']['total_restant'],
                'eleves_dettes'  => $rapport['debiteurs'],
            ],
            'historique'  => $historiqueComplet,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 8. Classement (rangs) d'une classe pour une période
    // ════════════════════════════════════════════════════════════
    public function rangsClasse(Request $request)
    {
        $request->validate([
            'classe_id'  => 'required|integer',
            'periode_id' => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $classe = Classe::where('id', $request->classe_id)->where('ecole_id', $ecoleId)->firstOrFail();
        $periode = PeriodeAcademique::findOrFail($request->periode_id);

        return response()->json($this->calculerRangsClasse($classe, $periode));
    }

    // Exporte le classement d'une classe pour une période en PDF.
    public function exporterRangsPdf(Request $request)
    {
        $request->validate([
            'classe_id'  => 'required|integer',
            'periode_id' => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;
        $ecole = $request->user()->ecole;

        $classe = Classe::where('id', $request->classe_id)->where('ecole_id', $ecoleId)->firstOrFail();
        $periode = PeriodeAcademique::findOrFail($request->periode_id);

        $classement = $this->calculerRangsClasse($classe, $periode);

        $pdf = Pdf::loadView('pdf.classement', [
            'ecole' => [
                'nom'              => $ecole->nom,
                'code_ecole'       => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'classement' => $classement,
            'genere_le'  => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download('classement_' . str_replace(' ', '_', $classe->nom) . '_' . str_replace(' ', '_', $periode->nom) . '.pdf');
    }

    // Calcule le classement pondéré (moyenne par élève selon les
    // coefficients de classe_matiere) et les rangs pour une classe et une
    // période données.
    private function calculerRangsClasse(Classe $classe, PeriodeAcademique $periode): array
    {
        $coefficients = ClasseMatiere::where('classe_id', $classe->id)
            ->with('matiere:id,nom')
            ->get()
            ->keyBy('matiere_id');

        $inscriptions = Inscription::where('classe_id', $classe->id)
            ->where('annee_academique_id', $periode->annee_academique_id)
            ->with('eleve')
            ->get();

        $eleves = $inscriptions->map(function ($inscription) use ($periode, $coefficients) {
            $notes = Note::where('eleve_id', $inscription->eleve_id)
                ->where('periode_id', $periode->id)
                ->where('statut', 'valide')
                ->get()
                ->keyBy('matiere_id');

            $totalPoints = 0;
            $totalCoef   = 0;
            $notesParMatiere = [];

            foreach ($coefficients as $matiereId => $classeMatiere) {
                $note = $notes->get($matiereId);
                $coef = $classeMatiere->coefficient;

                if ($note) {
                    $totalPoints += $note->valeur * $coef;
                    $totalCoef   += $coef;
                }

                $notesParMatiere[] = [
                    'matiere'     => $classeMatiere->matiere->nom,
                    'valeur'      => $note?->valeur,
                    'coefficient' => $coef,
                ];
            }

            $moyenne = $totalCoef > 0 ? round($totalPoints / $totalCoef, 2) : null;

            return [
                'eleve_id'          => $inscription->eleve_id,
                'nom'               => $inscription->eleve?->nom,
                'prenom'            => $inscription->eleve?->prenom,
                'photo_url'         => $inscription->eleve?->photo_url,
                'moyenne'           => $moyenne,
                'mention'           => $moyenne !== null ? $this->mention($moyenne) : null,
                'notes_par_matiere' => $notesParMatiere,
            ];
        });

        $avecMoyenne = $eleves->filter(fn($e) => $e['moyenne'] !== null)
            ->sortByDesc('moyenne')
            ->values();

        $sansMoyenne = $eleves->filter(fn($e) => $e['moyenne'] === null)->values();

        $classement = $avecMoyenne->map(function ($e, $index) {
            $e['rang'] = $index + 1;
            return $e;
        })->concat($sansMoyenne->map(function ($e) {
            $e['rang'] = null;
            return $e;
        }))->values();

        return [
            'classe_id'      => $classe->id,
            'classe_nom'     => $classe->nom,
            'periode_id'     => $periode->id,
            'periode_nom'    => $periode->nom,
            'moyenne_classe' => $avecMoyenne->isEmpty() ? null : round($avecMoyenne->avg('moyenne'), 2),
            'eleves'         => $classement,
        ];
    }

    private function mention(float $note): string
    {
        if ($note >= 18) return 'Excellent';
        if ($note >= 16) return 'Très Bien';
        if ($note >= 14) return 'Bien';
        if ($note >= 12) return 'Assez Bien';
        if ($note >= 10) return 'Passable';
        return 'Insuffisant';
    }

    // ════════════════════════════════════════════════════════════
    // 9. Élèves non en règle (paiement / absences / dossier)
    // ════════════════════════════════════════════════════════════
    public function elevesNonEnRegle(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        $motifs = $this->motifsDemandes($request);

        $annee = AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->first();

        if (!$annee) {
            return response()->json(['message' => 'Aucune année académique active.', 'classes' => []], 404);
        }

        return response()->json([
            'annee_id' => $annee->id,
            'motifs'   => $motifs,
            'classes'  => $this->calculerElevesNonEnRegle($ecoleId, $annee, $motifs),
        ]);
    }

    // Exporte la liste des élèves non en règle en PDF.
    public function exporterElevesNonEnReglePdf(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        $ecole = $request->user()->ecole;
        $motifs = $this->motifsDemandes($request);

        $annee = AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->firstOrFail();
        $classes = $this->calculerElevesNonEnRegle($ecoleId, $annee, $motifs);

        $pdf = Pdf::loadView('pdf.eleves_non_en_regle', [
            'ecole' => [
                'nom'              => $ecole->nom,
                'code_ecole'       => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'classes'   => $classes,
            'motifs'    => $motifs,
            'genere_le' => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download('eleves_non_en_regle.pdf');
    }

    // Exporte la liste des élèves non en règle en CSV (compatible Excel).
    public function exporterElevesNonEnRegleExcel(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        $motifs = $this->motifsDemandes($request);

        $annee = AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->firstOrFail();
        $classes = $this->calculerElevesNonEnRegle($ecoleId, $annee, $motifs);

        $callback = function () use ($classes) {
            $fichier = fopen('php://output', 'w');
            fwrite($fichier, "\xEF\xBB\xBF");
            fputcsv($fichier, ['Classe', 'Nom', 'Prénom', 'Dette (FCFA)', 'Absences non justifiées']);

            foreach ($classes as $eleves) {
                foreach ($eleves as $e) {
                    fputcsv($fichier, [
                        $e['classe_nom'],
                        $e['nom'],
                        $e['prenom'],
                        $e['motifs']['paiement']['montant_restant'] ?? '',
                        $e['motifs']['absences']['nombre_absences_non_justifiees'] ?? '',
                    ]);
                }
            }

            fclose($fichier);
        };

        return response()->stream($callback, 200, [
            'Content-Type'        => 'text/csv',
            'Content-Disposition' => 'attachment; filename="eleves_non_en_regle.csv"',
        ]);
    }

    private function motifsDemandes(Request $request): array
    {
        $motifs = $request->input('motif', ['paiement', 'absences']);
        return is_array($motifs) ? $motifs : [$motifs];
    }

    // Calcule, groupée par classe, la liste des élèves non en règle selon
    // les motifs demandés (paiement / absences). Le motif "dossier" n'a
    // pas encore de champ dédié dans le schéma et ne renvoie rien.
    private function calculerElevesNonEnRegle(int $ecoleId, AnneeAcademique $annee, array $motifs)
    {
        $parEleve = [];

        if (in_array('paiement', $motifs)) {
            $rapport = (new FraisScolaireController())->calculerRapportFinancier($ecoleId, $annee->id, null);
            foreach ($rapport['debiteurs'] as $d) {
                $parEleve[$d['eleve_id']]['eleve_id'] = $d['eleve_id'];
                $parEleve[$d['eleve_id']]['nom'] = $d['nom'];
                $parEleve[$d['eleve_id']]['prenom'] = $d['prenom'];
                $parEleve[$d['eleve_id']]['classe_id'] = $d['classe_id'];
                $parEleve[$d['eleve_id']]['classe_nom'] = $d['classe_nom'];
                $parEleve[$d['eleve_id']]['motifs']['paiement'] = [
                    'montant_restant' => $d['montant_restant'],
                ];
            }
        }

        if (in_array('absences', $motifs)) {
            $absences = Absence::whereHas('classe', fn($q) => $q->where('annee_academique_id', $annee->id))
                ->where('justifiee', false)
                ->select('eleve_id', DB::raw('COUNT(*) as total'))
                ->groupBy('eleve_id')
                ->having('total', '>', 5)
                ->with('eleve')
                ->get();

            foreach ($absences as $a) {
                $inscription = Inscription::where('eleve_id', $a->eleve_id)
                    ->where('annee_academique_id', $annee->id)
                    ->with('classe')
                    ->first();

                $parEleve[$a->eleve_id]['eleve_id'] = $a->eleve_id;
                $parEleve[$a->eleve_id]['nom'] = $a->eleve?->nom;
                $parEleve[$a->eleve_id]['prenom'] = $a->eleve?->prenom;
                $parEleve[$a->eleve_id]['classe_id'] = $inscription?->classe_id;
                $parEleve[$a->eleve_id]['classe_nom'] = $inscription?->classe?->nom;
                $parEleve[$a->eleve_id]['motifs']['absences'] = [
                    'nombre_absences_non_justifiees' => (int) $a->total,
                ];
            }
        }

        return collect($parEleve)->groupBy('classe_nom')->map(fn($eleves) => $eleves->values());
    }

    // ════════════════════════════════════════════════════════════
    // 10. Rapport complet d'une période
    // ════════════════════════════════════════════════════════════
    public function rapportPeriode(Request $request, $periodeId)
    {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->with('annee')
            ->findOrFail($periodeId);

        $moyennesParEleve = Note::where('periode_id', $periode->id)
            ->where('statut', 'valide')
            ->select('eleve_id', DB::raw('AVG(valeur) as moyenne'))
            ->groupBy('eleve_id')
            ->get();

        $enDifficulte = $moyennesParEleve->filter(fn($m) => $m->moyenne < 10)->sortBy('moyenne')->values();
        $excellents   = $moyennesParEleve->filter(fn($m) => $m->moyenne >= 16)->sortByDesc('moyenne')->values();

        $eleveIds = $moyennesParEleve->pluck('eleve_id');
        $eleves = \App\Models\Eleve::whereIn('id', $eleveIds)->get()->keyBy('id');

        $formatter = fn($m) => [
            'eleve_id' => $m->eleve_id,
            'nom'      => $eleves->get($m->eleve_id)?->nom,
            'prenom'   => $eleves->get($m->eleve_id)?->prenom,
            'moyenne'  => round($m->moyenne, 2),
        ];

        $paiements = Paiement::where('annee_academique_id', $periode->annee_academique_id)
            ->whereBetween('date_paiement', [$periode->date_debut, $periode->date_fin])
            ->sum('montant');

        $notesSaisies = Note::where('periode_id', $periode->id)->count();
        $notesValidees = Note::where('periode_id', $periode->id)->where('statut', 'valide')->count();

        return response()->json([
            'periode' => [
                'id'         => $periode->id,
                'nom'        => $periode->nom,
                'date_debut' => $periode->date_debut,
                'date_fin'   => $periode->date_fin,
                'statut'     => $periode->statut,
            ],
            'pedagogique' => [
                'notes_saisies'   => $notesSaisies,
                'notes_validees'  => $notesValidees,
                'moyenne_periode' => $moyennesParEleve->isEmpty() ? null : round($moyennesParEleve->avg('moyenne'), 2),
            ],
            'paiements_periode'  => $paiements,
            'eleves_en_difficulte' => $enDifficulte->map($formatter)->values(),
            'eleves_excellents'    => $excellents->map($formatter)->values(),
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 11. Journal des actions de l'école
    // ════════════════════════════════════════════════════════════
    public function journalActions(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $requete = JournalAction::where('ecole_id', $ecoleId)->with('auteur:id,name');

        if ($request->filled('annee_id')) {
            $annee = AnneeAcademique::where('id', $request->annee_id)->where('ecole_id', $ecoleId)->firstOrFail();
            $periodeIds = $annee->periodes()->pluck('id');

            $requete->where(function ($q) use ($annee, $periodeIds) {
                $q->where(function ($q2) use ($annee) {
                    $q2->where('entite_type', 'AnneeAcademique')->where('entite_id', $annee->id);
                })->orWhere(function ($q2) use ($periodeIds) {
                    $q2->where('entite_type', 'Periode')->whereIn('entite_id', $periodeIds);
                });
            });
        }

        $journal = $requete->orderByDesc('created_at')
            ->limit(200)
            ->get()
            ->map(fn($j) => [
                'id'              => $j->id,
                'entite_type'     => $j->entite_type,
                'entite_id'       => $j->entite_id,
                'action'          => $j->action,
                'utilisateur_nom' => $j->auteur?->name,
                'details'         => $j->details ? json_decode($j->details, true) : null,
                'created_at'      => $j->created_at,
            ]);

        return response()->json($journal);
    }

    // ── (legacy) Historique — ancienne table historique_annees ──
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

    // ── (legacy) Aperçu du passage des élèves (lecture seule) ──
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
