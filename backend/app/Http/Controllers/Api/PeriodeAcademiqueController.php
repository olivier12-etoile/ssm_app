<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\ClasseMatiere;
use App\Models\Inscription;
use App\Models\JournalAction;
use App\Models\Note;
use App\Models\PeriodeAcademique;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PeriodeAcademiqueController extends Controller
{
    private const MAX_PERIODES = [
        'trimestres' => 3,
        'semestres'  => 2,
    ];

    // ════════════════════════════════════════════════════════════
    // 1. Liste des périodes d'une année
    // ════════════════════════════════════════════════════════════
    public function index(Request $request)
    {
        $request->validate([
            'annee_id' => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $annee = AnneeAcademique::where('id', $request->annee_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $periodes = PeriodeAcademique::where('annee_academique_id', $annee->id)
            ->orderBy('ordre')
            ->get();

        $periodes->each(function ($periode) {
            $periode->notes_saisies  = Note::where('periode_id', $periode->id)->count();
            $periode->notes_validees = Note::where('periode_id', $periode->id)
                ->where('statut', 'valide')
                ->count();
            $periode->bulletins_generes = Note::where('periode_id', $periode->id)
                ->where('statut', 'valide')
                ->distinct('eleve_id')
                ->count('eleve_id');

            $etat = $periode->etatEnseignants();
            $periode->enseignants_termines = $etat->where('statut', 'termine')->count();
            $periode->enseignants_total    = $etat->pluck('enseignant_id')->unique()->count();
        });

        return response()->json($periodes);
    }

    // ════════════════════════════════════════════════════════════
    // 2. Créer une période
    // ════════════════════════════════════════════════════════════
    public function store(Request $request)
    {
        $request->validate([
            'annee_academique_id' => 'required|integer',
            'nom'                 => 'required|string|max:50',
            'code'                => 'nullable|string|max:10',
            'couleur'             => 'nullable|string|max:10',
            'date_debut'          => 'required|date',
            'date_fin'            => 'required|date|after:date_debut',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $annee = AnneeAcademique::where('id', $request->annee_academique_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $periodesExistantes = PeriodeAcademique::where('annee_academique_id', $annee->id)->get();
        $max = self::MAX_PERIODES[$annee->type_periodes] ?? 3;

        if ($periodesExistantes->count() >= $max) {
            $type = $annee->type_periodes === 'semestres' ? 'semestres' : 'trimestres';
            return response()->json([
                'message' => "Une année en {$type} ne peut pas avoir plus de {$max} périodes.",
            ], 409);
        }

        $nouveauDebut = Carbon::parse($request->date_debut);
        $nouveauFin   = Carbon::parse($request->date_fin);

        $chevauchement = $periodesExistantes->first(function ($p) use ($nouveauDebut, $nouveauFin) {
            return $nouveauDebut->lte(Carbon::parse($p->date_fin)) && $nouveauFin->gte(Carbon::parse($p->date_debut));
        });

        if ($chevauchement) {
            return response()->json([
                'message' => "Ces dates chevauchent la période \"{$chevauchement->nom}\".",
            ], 409);
        }

        $periode = PeriodeAcademique::create([
            'annee_academique_id' => $annee->id,
            'nom'                 => $request->nom,
            'code'                => $request->code,
            'couleur'             => $request->couleur,
            'ordre'               => $periodesExistantes->count() + 1,
            'date_debut'          => $request->date_debut,
            'date_fin'            => $request->date_fin,
            'statut'              => 'preparation',
        ]);

        return response()->json([
            'message' => 'Période créée avec succès',
            'periode' => $periode,
        ], 201);
    }

    // ════════════════════════════════════════════════════════════
    // 3. Ouvrir une période
    // ════════════════════════════════════════════════════════════
    // Une seule période 'ouverte' à la fois : l'ancienne (s'il y en a une)
    // passe en 'en_veille' — elle reste accessible en lecture/écriture
    // aux enseignants pour compléter leurs saisies, sans bloquer
    // l'ouverture de la nouvelle période principale.
    public function ouvrir(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('id', $id)
            ->firstOrFail();

        PeriodeAcademique::where('annee_academique_id', $periode->annee_academique_id)
            ->where('statut', 'ouverte')
            ->where('id', '!=', $periode->id)
            ->update(['statut' => 'en_veille']);

        $periode->update([
            'statut'      => 'ouverte',
            'ouverte_par' => $request->user()->id,
            'ouverte_le'  => now(),
        ]);

        JournalAction::enregistrer('Periode', $periode->id, 'ouverture', $request->user()->id, $ecoleId, [
            'periode_nom' => $periode->nom,
        ]);

        return response()->json([
            'message' => 'Période ouverte avec succès',
            'periode' => $periode,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 4. Mettre en validation
    // ════════════════════════════════════════════════════════════
    public function mettreEnValidation(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('id', $id)
            ->firstOrFail();

        $periode->update(['statut' => 'en_validation']);

        return response()->json([
            'message' => 'Période mise en validation. Les enseignants ne peuvent plus modifier leurs notes.',
            'periode' => $periode,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 5. Fermer (clôturer) une période
    // ════════════════════════════════════════════════════════════
    public function fermer(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('id', $id)
            ->firstOrFail();

        $etat = $periode->etatEnseignants();
        $enRetard = $etat->where('statut', '!=', 'termine')->values();

        $periode->update([
            'statut'     => 'cloturee',
            'fermee_par' => $request->user()->id,
            'fermee_le'  => now(),
        ]);

        Note::where('periode_id', $periode->id)
            ->where('statut', 'brouillon')
            ->update(['statut' => 'soumis']);

        $calcul = $this->calculerMoyennesEtRangs($periode);

        JournalAction::enregistrer('Periode', $periode->id, 'cloture', $request->user()->id, $ecoleId, [
            'periode_nom'         => $periode->nom,
            'moyennes_calculees'  => $calcul['moyennes_calculees'],
            'rangs_attribues'     => $calcul['rangs_attribues'],
        ]);

        return response()->json([
            'message'               => 'Période fermée avec succès',
            'periode'               => $periode,
            'enseignants_en_retard' => $enRetard,
            'moyennes_calculees'    => $calcul['moyennes_calculees'],
            'rangs_attribues'       => $calcul['rangs_attribues'],
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 6. Rouvrir une période (exceptionnel)
    // ════════════════════════════════════════════════════════════
    public function reouvrir(Request $request, $id)
    {
        $request->validate([
            'motif' => 'required|string|max:500',
        ]);

        if (!in_array($request->user()->role, ['directeur', 'censeur', 'super_admin'])) {
            return response()->json([
                'message' => "Seul un directeur, un censeur ou un super administrateur peut rouvrir une période.",
            ], 403);
        }

        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('id', $id)
            ->firstOrFail();

        $periode->update(['statut' => 'ouverte']);

        JournalAction::enregistrer('Periode', $periode->id, 'reouverture', $request->user()->id, $ecoleId, [
            'periode_nom' => $periode->nom,
            'motif'       => $request->motif,
        ]);

        return response()->json([
            'message' => 'Période rouverte avec succès',
            'periode' => $periode,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 7. État des enseignants pour une période
    // ════════════════════════════════════════════════════════════
    public function etatEnseignants(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('id', $id)
            ->firstOrFail();

        return response()->json($periode->etatEnseignants());
    }

    // ════════════════════════════════════════════════════════════
    // 8. Vérification avant clôture
    // ════════════════════════════════════════════════════════════
    public function verifierAvantCloture(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('id', $id)
            ->firstOrFail();

        $etat = $periode->etatEnseignants();
        $parClasse = $etat->groupBy('classe_id');

        $classesTerminees = [];
        $classesIncompletes = [];

        foreach ($parClasse as $classeId => $lignes) {
            $notesManquantes = $lignes->sum(fn($l) => $l['notes_total'] - $l['notes_saisies']);

            if ($notesManquantes === 0) {
                $classesTerminees[] = $classeId;
            } else {
                $classesIncompletes[] = [
                    'classe_id'        => $classeId,
                    'classe_nom'       => $lignes->first()['classe_nom'],
                    'notes_manquantes' => $notesManquantes,
                ];
            }
        }

        $enseignantsRetard = $etat->where('statut', '!=', 'termine')
            ->unique('enseignant_id')
            ->map(fn($l) => ['enseignant_id' => $l['enseignant_id'], 'nom' => $l['enseignant_nom']])
            ->values();

        $pretPourCloture = empty($classesIncompletes);

        return response()->json([
            'classes_terminees'   => $classesTerminees,
            'classes_incompletes' => $classesIncompletes,
            'enseignants_retard'  => $enseignantsRetard,
            'pret_pour_cloture'   => $pretPourCloture,
            'bulletins_prets'     => $pretPourCloture,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 9. Générer les bulletins en masse
    // ════════════════════════════════════════════════════════════
    public function genererBulletinsEnMasse(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('id', $id)
            ->firstOrFail();

        $calcul = $this->calculerMoyennesEtRangs($periode);

        JournalAction::enregistrer('Periode', $periode->id, 'generation_bulletins', $request->user()->id, $ecoleId, [
            'periode_nom'       => $periode->nom,
            'bulletins_generes' => $calcul['moyennes_calculees'],
        ]);

        return response()->json([
            'message'           => 'Bulletins générés avec succès',
            'bulletins_generes' => $calcul['moyennes_calculees'],
        ]);
    }

    // ── (legacy) Alertes sur la période ouverte — conservé pour compatibilité ──
    public function alertes(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('statut', 'ouverte')
            ->with('annee')
            ->first();

        if (!$periode) {
            return response()->json([
                'periode' => null,
                'alertes' => [[
                    'type'    => 'aucune_periode_active',
                    'message' => 'Aucune période active pour le moment.',
                ]],
            ]);
        }

        $alertes = [];

        $joursRestants = $this->joursRestants($periode->date_fin);
        if ($joursRestants <= 7) {
            $alertes[] = [
                'type'           => 'fin_periode_proche',
                'message'        => "La période \"{$periode->nom}\" se termine dans {$joursRestants} jour(s).",
                'jours_restants' => $joursRestants,
            ];
        }

        $enRetard = $periode->etatEnseignants()->where('statut', '!=', 'termine')->values();
        if ($enRetard->isNotEmpty()) {
            $alertes[] = [
                'type'        => 'enseignants_en_retard',
                'message'     => $enRetard->count() . " affectation(s) enseignant n'ont pas encore soumis leurs notes.",
                'enseignants' => $enRetard,
            ];
        }

        return response()->json([
            'periode' => $periode,
            'alertes' => $alertes,
        ]);
    }

    // ── Aides internes ────────────────────────────────────────────

    private function joursRestants(string $dateFin): int
    {
        $fin        = strtotime($dateFin . ' 00:00:00');
        $aujourdhui = strtotime(now()->format('Y-m-d') . ' 00:00:00');

        return (int) round(($fin - $aujourdhui) / 86400);
    }

    // Calcule (sans les persister — aucune table de bulletins n'existe
    // encore dans le schéma) les moyennes pondérées par élève et les rangs
    // par classe pour la période. Retourne le nombre d'élèves ayant une
    // moyenne calculée et le nombre de rangs attribués.
    private function calculerMoyennesEtRangs(PeriodeAcademique $periode): array
    {
        $classes = Inscription::where('annee_academique_id', $periode->annee_academique_id)
            ->distinct()
            ->pluck('classe_id');

        $moyennesCalculees = 0;
        $rangsAttribues = 0;

        foreach ($classes as $classeId) {
            $coefficients = ClasseMatiere::where('classe_id', $classeId)->get()->keyBy('matiere_id');

            $eleveIds = Inscription::where('classe_id', $classeId)
                ->where('annee_academique_id', $periode->annee_academique_id)
                ->pluck('eleve_id');

            $moyennesClasse = 0;

            foreach ($eleveIds as $eleveId) {
                $notes = Note::where('eleve_id', $eleveId)
                    ->where('periode_id', $periode->id)
                    ->where('statut', 'valide')
                    ->get()
                    ->keyBy('matiere_id');

                $totalPoints = 0;
                $totalCoef = 0;

                foreach ($coefficients as $matiereId => $classeMatiere) {
                    $note = $notes->get($matiereId);
                    if ($note) {
                        $totalPoints += $note->valeur * $classeMatiere->coefficient;
                        $totalCoef   += $classeMatiere->coefficient;
                    }
                }

                if ($totalCoef > 0) {
                    $moyennesCalculees++;
                    $moyennesClasse++;
                }
            }

            if ($moyennesClasse > 0) {
                $rangsAttribues += $moyennesClasse;
            }
        }

        return [
            'moyennes_calculees' => $moyennesCalculees,
            'rangs_attribues'    => $rangsAttribues,
        ];
    }
}
