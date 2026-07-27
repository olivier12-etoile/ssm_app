<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\Note;
use App\Models\PeriodeAcademique;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PeriodeAcademiqueController extends Controller
{
    // ── 1. Liste des périodes d'une année ────────────────────────
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
            ->orderBy('date_debut')
            ->get();

        $periodes->each(function ($periode) {
            $periode->notes_saisies  = Note::where('periode_id', $periode->id)->count();
            $periode->notes_validees = Note::where('periode_id', $periode->id)
                ->where('statut', 'valide')
                ->count();

            [$total, $enRetard] = $this->enseignantsEnRetard($periode);
            $periode->enseignants_termines = $total - count($enRetard);
        });

        return response()->json($periodes);
    }

    // ── 2. Créer une période ─────────────────────────────────────
    public function store(Request $request)
    {
        $request->validate([
            'annee_academique_id' => 'required|integer',
            'nom'                 => 'required|string|max:50',
            'code'                => 'nullable|string|max:10',
            'date_debut'          => 'required|date',
            'date_fin'            => 'required|date|after:date_debut',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $annee = AnneeAcademique::where('id', $request->annee_academique_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $periodesExistantes = PeriodeAcademique::where('annee_academique_id', $annee->id)->get();

        if ($periodesExistantes->count() >= 3) {
            return response()->json([
                'message' => 'Une année académique ne peut pas avoir plus de 3 périodes.',
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
            'date_debut'          => $request->date_debut,
            'date_fin'            => $request->date_fin,
            'statut'              => 'planifie',
        ]);

        return response()->json([
            'message' => 'Période créée avec succès',
            'periode' => $periode,
        ], 201);
    }

    // ── 3. Ouvrir une période ─────────────────────────────────────
    // Une seule période 'ouvert' à la fois : l'ancienne (s'il y en a une)
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
            ->where('statut', 'ouvert')
            ->where('id', '!=', $periode->id)
            ->update(['statut' => 'en_veille']);

        $periode->update([
            'statut'      => 'ouvert',
            'ouverte_par' => $request->user()->id,
            'ouverte_le'  => now(),
        ]);

        return response()->json([
            'message' => 'Période ouverte avec succès',
            'periode' => $periode,
        ]);
    }

    // ── 4. Fermer une période ─────────────────────────────────────
    public function fermer(Request $request, $id)
    {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('id', $id)
            ->firstOrFail();

        [, $enRetard] = $this->enseignantsEnRetard($periode);

        $periode->update([
            'statut'     => 'ferme',
            'fermee_par' => $request->user()->id,
            'fermee_le'  => now(),
        ]);

        Note::where('periode_id', $periode->id)
            ->where('statut', 'brouillon')
            ->update(['statut' => 'soumis']);

        return response()->json([
            'message'               => 'Période fermée avec succès',
            'periode'               => $periode,
            'enseignants_en_retard' => $enRetard,
        ]);
    }

    // ── 5. Alertes sur la période ouverte ─────────────────────────
    public function alertes(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        $periode = PeriodeAcademique::whereHas('annee', fn($q) => $q->where('ecole_id', $ecoleId))
            ->where('statut', 'ouvert')
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

        [, $enRetard] = $this->enseignantsEnRetard($periode);
        if (!empty($enRetard)) {
            $alertes[] = [
                'type'        => 'enseignants_en_retard',
                'message'     => count($enRetard) . " enseignant(s) n'ont pas encore soumis leurs notes.",
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

    // Retourne [nombre total d'enseignants affectés, liste de ceux en retard].
    // Un enseignant est « en retard » s'il lui reste des notes en brouillon
    // pour cette période, ou s'il n'a encore saisi aucune note.
    private function enseignantsEnRetard(PeriodeAcademique $periode): array
    {
        $enseignants = DB::table('enseignant_classe_matiere')
            ->join('classes', 'classes.id', '=', 'enseignant_classe_matiere.classe_id')
            ->join('users', 'users.id', '=', 'enseignant_classe_matiere.enseignant_id')
            ->where('classes.annee_academique_id', $periode->annee_academique_id)
            ->select('enseignant_classe_matiere.enseignant_id', 'users.name')
            ->distinct()
            ->get();

        $enRetard = [];
        foreach ($enseignants as $e) {
            $aDesBrouillons = Note::where('enseignant_id', $e->enseignant_id)
                ->where('periode_id', $periode->id)
                ->where('statut', 'brouillon')
                ->exists();

            $aDesNotes = Note::where('enseignant_id', $e->enseignant_id)
                ->where('periode_id', $periode->id)
                ->exists();

            if ($aDesBrouillons || !$aDesNotes) {
                $enRetard[] = [
                    'enseignant_id' => $e->enseignant_id,
                    'nom'           => $e->name,
                ];
            }
        }

        return [$enseignants->count(), $enRetard];
    }
}