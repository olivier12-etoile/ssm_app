<?php

namespace App\Services;

use App\Models\ClasseMatiere;
use App\Models\Eleve;
use App\Models\Note;
use App\Models\PeriodeAcademique;
use Illuminate\Support\Collection;

/**
 * Centralise tous les calculs statistiques du module Notes & Évaluations.
 *
 * Important : ce service ne filtre PAS par statut de note (brouillon,
 * en_attente_validation, validee...). Il reflète l'état courant des notes
 * saisies, y compris pendant la phase de saisie elle-même (avant toute
 * validation) — c'est justement à ce moment que les moyennes et anomalies
 * sont les plus utiles à l'enseignant.
 *
 * La "moyenne de matière" d'un élève (devoir + composition) réutilise la
 * formule déjà établie dans MoyenneCalculService (moyenne simple des deux,
 * avec repli si l'un des deux manque), pour rester cohérente avec le reste
 * de l'application.
 */
class NoteCalculService
{
    // ── Moyenne de la classe pour une matière/période (moyenne brute de
    // toutes les notes saisies, devoirs et compositions confondus) ──
    public function moyenneMatiere(int $classeId, int $matiereId, int $periodeId): ?float
    {
        $moyenne = Note::where('classe_id', $classeId)
            ->where('matiere_id', $matiereId)
            ->where('periode_id', $periodeId)
            ->avg('valeur');

        return $moyenne !== null ? round((float) $moyenne, 2) : null;
    }

    // ── Moyenne générale pondérée d'un élève sur une période, toutes
    // matières confondues (pondération = coefficient enregistré sur la
    // note au moment de la saisie) ──
    public function moyenneEleve(int $eleveId, int $periodeId): ?float
    {
        $periode = PeriodeAcademique::findOrFail($periodeId);

        $classeId = Eleve::findOrFail($eleveId)->inscriptions()
            ->where('annee_academique_id', $periode->annee_academique_id)
            ->value('classe_id');

        if (!$classeId) {
            return null;
        }

        $matieresIds = ClasseMatiere::where('classe_id', $classeId)->pluck('matiere_id');

        $totalPoints = 0.0;
        $totalCoefficients = 0.0;

        foreach ($matieresIds as $matiereId) {
            $detail = $this->detailMatiereEleve($eleveId, $matiereId, $periodeId);

            if ($detail['moyenne'] === null || $detail['coefficient'] <= 0) {
                continue;
            }

            $totalPoints += $detail['moyenne'] * $detail['coefficient'];
            $totalCoefficients += $detail['coefficient'];
        }

        return $totalCoefficients > 0 ? round($totalPoints / $totalCoefficients, 2) : null;
    }

    public function meilleureNote(int $classeId, int $matiereId, int $periodeId): ?float
    {
        $valeur = Note::where('classe_id', $classeId)
            ->where('matiere_id', $matiereId)
            ->where('periode_id', $periodeId)
            ->max('valeur');

        return $valeur !== null ? (float) $valeur : null;
    }

    public function plusFaibleNote(int $classeId, int $matiereId, int $periodeId): ?float
    {
        $valeur = Note::where('classe_id', $classeId)
            ->where('matiere_id', $matiereId)
            ->where('periode_id', $periodeId)
            ->min('valeur');

        return $valeur !== null ? (float) $valeur : null;
    }

    // ── % d'élèves dont la moyenne de matière (devoir+composition) est
    // >= seuil, parmi les élèves ayant au moins une note dans la matière ──
    public function tauxReussite(int $classeId, int $matiereId, int $periodeId, float $seuil = 10): float
    {
        $moyennes = $this->elevesClasseParPeriode($classeId, $periodeId)
            ->map(fn (Eleve $eleve) => $this->detailMatiereEleve($eleve->id, $matiereId, $periodeId)['moyenne'])
            ->filter(fn ($m) => $m !== null);

        if ($moyennes->isEmpty()) {
            return 0.0;
        }

        $reussis = $moyennes->filter(fn ($m) => $m >= $seuil)->count();

        return round($reussis / $moyennes->count() * 100, 1);
    }

    // ── Rang de l'élève dans la matière (1 = meilleure moyenne) ──
    public function rangEleveMatiere(int $eleveId, int $classeId, int $matiereId, int $periodeId): ?int
    {
        $moyennes = $this->elevesClasseParPeriode($classeId, $periodeId)
            ->mapWithKeys(fn (Eleve $eleve) => [
                $eleve->id => $this->detailMatiereEleve($eleve->id, $matiereId, $periodeId)['moyenne'],
            ])
            ->filter(fn ($m) => $m !== null)
            ->sortByDesc(fn ($m) => $m);

        return $this->rangDans($moyennes, $eleveId);
    }

    // ── Rang général de l'élève (moyenne pondérée toutes matières) ──
    public function rangEleveGeneral(int $eleveId, int $classeId, int $periodeId): ?int
    {
        $moyennes = $this->elevesClasseParPeriode($classeId, $periodeId)
            ->mapWithKeys(fn (Eleve $eleve) => [$eleve->id => $this->moyenneEleve($eleve->id, $periodeId)])
            ->filter(fn ($m) => $m !== null)
            ->sortByDesc(fn ($m) => $m);

        return $this->rangDans($moyennes, $eleveId);
    }

    // ── Alertes de cohérence sur les notes d'une classe/matière/période ──
    public function detecterAnomalies(int $classeId, int $matiereId, int $periodeId): array
    {
        $eleves = $this->elevesClasseParPeriode($classeId, $periodeId);

        $notes = Note::where('classe_id', $classeId)
            ->where('matiere_id', $matiereId)
            ->where('periode_id', $periodeId)
            ->get();

        $alertes = [];

        // 1. Notes manquantes (devoir et/ou composition non saisis)
        $notesParEleve = $notes->groupBy('eleve_id');
        $elevesIncomplets = $eleves
            ->map(function (Eleve $eleve) use ($notesParEleve) {
                $typesSaisis = $notesParEleve->get($eleve->id, collect())->pluck('type_evaluation');
                $typesManquants = collect(['devoir', 'composition'])->diff($typesSaisis)->values();

                return $typesManquants->isEmpty() ? null : [
                    'eleve_id' => $eleve->id,
                    'nom' => $eleve->nom,
                    'prenom' => $eleve->prenom,
                    'types_manquants' => $typesManquants,
                ];
            })
            ->filter()
            ->values();

        if ($elevesIncomplets->isNotEmpty()) {
            $alertes[] = [
                'type' => 'notes_manquantes',
                'gravite' => 'avertissement',
                'message' => "{$elevesIncomplets->count()} élève(s) ont des notes manquantes pour cette matière.",
                'details' => $elevesIncomplets,
            ];
        }

        // 2. Notes hors limites (sécurité, la validation à la saisie
        // devrait déjà empêcher ce cas)
        $horsLimites = $notes->filter(fn (Note $n) => $n->valeur < 0 || $n->valeur > 20);
        if ($horsLimites->isNotEmpty()) {
            $alertes[] = [
                'type' => 'notes_hors_limites',
                'gravite' => 'critique',
                'message' => "{$horsLimites->count()} note(s) hors des limites autorisées (0 à 20).",
                'details' => $horsLimites->map(fn (Note $n) => [
                    'note_id' => $n->id,
                    'eleve_id' => $n->eleve_id,
                    'valeur' => (float) $n->valeur,
                ])->values(),
            ];
        }

        // 3. Toutes les notes identiques (variance nulle, à partir de 4 notes)
        if ($notes->count() > 3) {
            $valeurs = $notes->map(fn (Note $n) => (float) $n->valeur);
            if ($this->variance($valeurs) == 0.0) {
                $alertes[] = [
                    'type' => 'notes_identiques',
                    'gravite' => 'avertissement',
                    'message' => "Toutes les notes saisies sont identiques ({$valeurs->first()}/20).",
                ];
            }
        }

        // 4. Moyenne anormale
        $moyenne = $this->moyenneMatiere($classeId, $matiereId, $periodeId);
        if ($moyenne !== null && ($moyenne < 5 || $moyenne > 18)) {
            $sens = $moyenne < 5 ? 'anormalement basse' : 'anormalement élevée';
            $alertes[] = [
                'type' => 'moyenne_anormale',
                'gravite' => 'avertissement',
                'message' => "La moyenne de la classe ({$moyenne}/20) est {$sens}.",
            ];
        }

        return $alertes;
    }

    // ── Aides internes ────────────────────────────────────────────

    // Moyenne de matière d'un élève (devoir + composition) et coefficient
    // associé (pris sur la note elle-même, snapshot au moment de la saisie).
    private function detailMatiereEleve(int $eleveId, int $matiereId, int $periodeId): array
    {
        $notes = Note::where('eleve_id', $eleveId)
            ->where('matiere_id', $matiereId)
            ->where('periode_id', $periodeId)
            ->get();

        $devoir = $notes->firstWhere('type_evaluation', 'devoir');
        $composition = $notes->firstWhere('type_evaluation', 'composition');

        $moyenne = MoyenneCalculService::moyenneFinale(
            $devoir ? [(float) $devoir->valeur] : [],
            $composition?->valeur
        );

        $coefficient = (float) ($devoir->coefficient ?? $composition->coefficient ?? 0);

        return ['moyenne' => $moyenne, 'coefficient' => $coefficient];
    }

    private function elevesClasseParPeriode(int $classeId, int $periodeId): Collection
    {
        $periode = PeriodeAcademique::findOrFail($periodeId);

        return Eleve::whereHas('inscriptions', fn ($q) => $q
            ->where('classe_id', $classeId)
            ->where('annee_academique_id', $periode->annee_academique_id))
            ->orderBy('nom')
            ->get();
    }

    private function rangDans(Collection $moyennesTriees, int $eleveId): ?int
    {
        if (!$moyennesTriees->has($eleveId)) {
            return null;
        }

        return $moyennesTriees->keys()->search($eleveId) + 1;
    }

    private function variance(Collection $valeurs): float
    {
        $n = $valeurs->count();
        if ($n === 0) {
            return 0.0;
        }

        $moyenne = $valeurs->avg();

        return round($valeurs->reduce(fn ($carry, $v) => $carry + ($v - $moyenne) ** 2, 0) / $n, 4);
    }
}
