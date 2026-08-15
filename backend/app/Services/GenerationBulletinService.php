<?php

namespace App\Services;

use App\Models\Absence;
use App\Models\Bulletin;
use App\Models\Classe;
use App\Models\ClasseMatiere;
use App\Models\Eleve;
use App\Models\Inscription;
use App\Models\PeriodeAcademique;
use App\Models\RegleAppreciation;
use App\Models\Sanction;
use App\Models\SaisieNote;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Génération automatique des bulletins (module Bulletins). S'appuie sur
 * NoteCalculService::detailMatiereEleve() pour rester cohérent avec les
 * moyennes de matière déjà affichées ailleurs dans l'application (même
 * formule devoir+composition, même coefficient snapshot).
 *
 * Note sur "matière validée" : on considère qu'une matière d'une classe est
 * validée pour une période dès lors que toutes ses saisies_notes
 * (classe/matière/période, une par enseignant) sont au statut "validee".
 * Une matière sans aucune SaisieNote est traitée comme non validée (saisie
 * jamais commencée).
 */
class GenerationBulletinService
{
    public function __construct(private NoteCalculService $noteCalculService)
    {
    }

    public function genererPourEleve(int $eleveId, int $periodeId): Bulletin
    {
        $eleve = Eleve::findOrFail($eleveId);
        $periode = PeriodeAcademique::findOrFail($periodeId);

        if (Bulletin::where('eleve_id', $eleveId)->where('periode_id', $periodeId)->exists()) {
            throw new RuntimeException(
                "Un bulletin existe déjà pour {$eleve->nom} {$eleve->prenom} sur cette période. "
                . 'Utilisez la régénération (si non validé) ou une correction (si déjà validé).'
            );
        }

        $classeId = Inscription::where('eleve_id', $eleveId)
            ->where('annee_academique_id', $periode->annee_academique_id)
            ->value('classe_id');

        if (!$classeId) {
            throw new RuntimeException(
                "Impossible de générer le bulletin : {$eleve->nom} {$eleve->prenom} n'est inscrit(e) dans aucune classe pour cette période."
            );
        }

        $classe = Classe::findOrFail($classeId);

        $matieresNonValidees = $this->matieresNonValidees($classeId, $periodeId);
        if ($matieresNonValidees->isNotEmpty()) {
            $noms = $matieresNonValidees->pluck('nom_matiere')->implode(', ');
            throw new RuntimeException(
                "Impossible de générer le bulletin : {$matieresNonValidees->count()} matière(s) non validée(s) ({$noms})."
            );
        }

        $matieresClasse = ClasseMatiere::where('classe_id', $classeId)->with('matiere')->get();

        $lignes = [];
        $totalPoints = 0.0;
        $totalCoefficients = 0.0;

        foreach ($matieresClasse as $classeMatiere) {
            $detail = $this->noteCalculService->detailMatiereEleve($eleveId, $classeMatiere->matiere_id, $periodeId);

            if ($detail['moyenne'] === null) {
                throw new RuntimeException(
                    "Impossible de générer le bulletin : notes manquantes pour {$eleve->nom} {$eleve->prenom} en {$classeMatiere->matiere->nom}."
                );
            }

            $coefficient = (float) $classeMatiere->coefficient;
            $moyenneClasse = $this->noteCalculService->moyenneMatiere($classeId, $classeMatiere->matiere_id, $periodeId);

            // Pas de champ d'appréciation manuelle sur Note à ce jour : le
            // libellé est toujours calculé automatiquement via le barème de
            // l'école. Reste modifiable ensuite via une correction de bulletin.
            $appreciation = $this->appreciationAutomatique($detail['moyenne'], $eleve->ecole_id);

            $lignes[] = [
                'matiere_id' => $classeMatiere->matiere_id,
                'nom_matiere' => $classeMatiere->matiere->nom,
                'coefficient' => $coefficient,
                'note' => $detail['moyenne'],
                'moyenne_matiere_classe' => $moyenneClasse,
                'appreciation_matiere' => $appreciation,
            ];

            $totalPoints += $detail['moyenne'] * $coefficient;
            $totalCoefficients += $coefficient;
        }

        if ($totalCoefficients <= 0) {
            throw new RuntimeException(
                "Impossible de générer le bulletin : la classe {$classe->nom} n'a aucune matière avec un coefficient valide."
            );
        }

        $moyenneGenerale = round($totalPoints / $totalCoefficients, 2);

        [$absencesJustifiees, $absencesNonJustifiees, $retards] = $this->statistiquesPresence($eleveId, $periode);

        $effectifClasse = Inscription::where('classe_id', $classeId)
            ->where('annee_academique_id', $periode->annee_academique_id)
            ->count();

        return DB::transaction(function () use (
            $eleve,
            $classe,
            $periode,
            $lignes,
            $moyenneGenerale,
            $totalPoints,
            $totalCoefficients,
            $absencesJustifiees,
            $absencesNonJustifiees,
            $retards,
            $effectifClasse
        ) {
            $bulletin = Bulletin::create([
                'ecole_id' => $eleve->ecole_id,
                'eleve_id' => $eleve->id,
                'classe_id' => $classe->id,
                'annee_scolaire_id' => $periode->annee_academique_id,
                'periode_id' => $periode->id,
                'moyenne_generale' => $moyenneGenerale,
                'effectif_classe' => $effectifClasse,
                'total_coefficients' => $totalCoefficients,
                'total_points' => $totalPoints,
                'absences_justifiees' => $absencesJustifiees,
                'absences_non_justifiees' => $absencesNonJustifiees,
                'retards' => $retards,
                'statut' => 'genere',
                'genere_par' => auth()->id(),
                'professeur_principal_id' => $classe->professeur_principal_id,
            ]);

            foreach ($lignes as $ligne) {
                $bulletin->details()->create($ligne);
            }

            return $bulletin->load('details');
        });
    }

    public function genererPourClasse(int $classeId, int $periodeId): array
    {
        $periode = PeriodeAcademique::findOrFail($periodeId);

        $eleves = Eleve::whereHas('inscriptions', fn ($q) => $q
            ->where('classe_id', $classeId)
            ->where('annee_academique_id', $periode->annee_academique_id))
            ->orderBy('nom')
            ->get();

        $reussis = [];
        $echecs = [];

        foreach ($eleves as $eleve) {
            try {
                $bulletin = $this->genererPourEleve($eleve->id, $periodeId);
                $reussis[] = [
                    'eleve_id' => $eleve->id,
                    'nom' => $eleve->nom,
                    'prenom' => $eleve->prenom,
                    'bulletin_id' => $bulletin->id,
                ];
            } catch (RuntimeException $e) {
                $echecs[] = [
                    'eleve_id' => $eleve->id,
                    'nom' => $eleve->nom,
                    'prenom' => $eleve->prenom,
                    'raison' => $e->getMessage(),
                ];
            }
        }

        if (!empty($reussis)) {
            $this->calculerRangs($classeId, $periodeId);
        }

        return [
            'classe_id' => $classeId,
            'periode_id' => $periodeId,
            'total_eleves' => $eleves->count(),
            'nombre_reussis' => count($reussis),
            'nombre_echecs' => count($echecs),
            'reussis' => $reussis,
            'echecs' => $echecs,
        ];
    }

    /**
     * Rangs par moyenne générale décroissante, ex-aequo compris (même
     * moyenne = même rang, rang suivant sauté : 1er, 2e, 2e, 4e).
     */
    public function calculerRangs(int $classeId, int $periodeId): void
    {
        $bulletins = Bulletin::where('classe_id', $classeId)
            ->where('periode_id', $periodeId)
            ->orderByDesc('moyenne_generale')
            ->get();

        $rangs = [];
        $rangCourant = 0;
        $moyennePrecedente = null;

        foreach ($bulletins as $index => $bulletin) {
            $moyenne = (float) $bulletin->moyenne_generale;

            if ($moyennePrecedente === null || $moyenne !== $moyennePrecedente) {
                $rangCourant = $index + 1;
            }

            $rangs[$bulletin->id] = $rangCourant;
            $moyennePrecedente = $moyenne;
        }

        $effectifParRang = collect($rangs)->countBy();

        foreach ($bulletins as $bulletin) {
            $rang = $rangs[$bulletin->id];
            $bulletin->update([
                'rang' => $rang,
                'rang_ex_aequo' => $effectifParRang[$rang] > 1,
            ]);
        }
    }

    public function regenererPourEleve(int $eleveId, int $periodeId): Bulletin
    {
        $bulletin = Bulletin::where('eleve_id', $eleveId)->where('periode_id', $periodeId)->first();

        if ($bulletin) {
            if ($bulletin->statut !== 'genere') {
                throw new RuntimeException(
                    "Ce bulletin est déjà {$bulletin->statut} : utilisez la correction plutôt que la régénération."
                );
            }

            $bulletin->delete();
        }

        $nouveauBulletin = $this->genererPourEleve($eleveId, $periodeId);

        // La moyenne de l'élève régénéré a pu changer : les rangs de toute
        // la classe doivent être recalculés pour rester cohérents.
        $this->calculerRangs($nouveauBulletin->classe_id, $periodeId);

        return $nouveauBulletin->fresh('details');
    }

    public function appreciationAutomatique(float $note, ?int $ecoleId = null): ?string
    {
        return RegleAppreciation::pourNote($note, $ecoleId)?->libelle_appreciation;
    }

    /**
     * Pour chaque élève de la classe, indique si son bulletin est déjà
     * généré et, sinon, la raison du blocage (matière(s) de classe non
     * validée(s), ou notes manquantes propres à cet élève).
     */
    public function statutGeneration(int $classeId, int $periodeId): array
    {
        $periode = PeriodeAcademique::findOrFail($periodeId);
        $matieresNonValidees = $this->matieresNonValidees($classeId, $periodeId);
        $matieresClasse = $matieresNonValidees->isEmpty()
            ? ClasseMatiere::where('classe_id', $classeId)->with('matiere')->get()
            : collect();

        $eleves = Eleve::whereHas('inscriptions', fn ($q) => $q
            ->where('classe_id', $classeId)
            ->where('annee_academique_id', $periode->annee_academique_id))
            ->orderBy('nom')
            ->get();

        return $eleves->map(function (Eleve $eleve) use ($periodeId, $matieresNonValidees, $matieresClasse) {
            $bulletin = Bulletin::where('eleve_id', $eleve->id)->where('periode_id', $periodeId)->first();

            $ligne = [
                'eleve_id' => $eleve->id,
                'nom' => $eleve->nom,
                'prenom' => $eleve->prenom,
                'genere' => (bool) $bulletin,
                'bulletin_id' => $bulletin?->id,
                'statut_bulletin' => $bulletin?->statut,
                'blocage' => null,
            ];

            if ($bulletin) {
                return $ligne;
            }

            if ($matieresNonValidees->isNotEmpty()) {
                $noms = $matieresNonValidees->pluck('nom_matiere')->implode(', ');
                $ligne['blocage'] = "Matière(s) non validée(s) pour la classe : {$noms}.";
                return $ligne;
            }

            $matiereManquante = $matieresClasse->first(
                fn (ClasseMatiere $cm) => $this->noteCalculService
                    ->detailMatiereEleve($eleve->id, $cm->matiere_id, $periodeId)['moyenne'] === null
            );

            if ($matiereManquante) {
                $ligne['blocage'] = "Notes manquantes en {$matiereManquante->matiere->nom}.";
            }

            return $ligne;
        })->values()->all();
    }

    // ── Aides internes ────────────────────────────────────────────

    private function matieresNonValidees(int $classeId, int $periodeId): Collection
    {
        return ClasseMatiere::where('classe_id', $classeId)
            ->with('matiere')
            ->get()
            ->map(function (ClasseMatiere $classeMatiere) use ($classeId, $periodeId) {
                $saisies = SaisieNote::where('classe_id', $classeId)
                    ->where('matiere_id', $classeMatiere->matiere_id)
                    ->where('periode_id', $periodeId)
                    ->get();

                if ($saisies->isNotEmpty() && $saisies->every(fn (SaisieNote $s) => $s->statut === 'validee')) {
                    return null;
                }

                $motif = match (true) {
                    $saisies->isEmpty() => 'saisie non commencée',
                    $saisies->contains(fn (SaisieNote $s) => $s->statut === 'rejetee') => 'saisie rejetée',
                    $saisies->contains(fn (SaisieNote $s) => $s->statut === 'en_attente_validation') => 'en attente de validation',
                    default => 'saisie en cours',
                };

                return [
                    'matiere_id' => $classeMatiere->matiere_id,
                    'nom_matiere' => "{$classeMatiere->matiere->nom} ({$motif})",
                ];
            })
            ->filter()
            ->values();
    }

    // absences_justifiees/non_justifiees : module Absences (table absences,
    // champ justifiee). retards : le module Absences ne distingue pas les
    // retards -- ils sont enregistrés comme Sanction de type "retard"
    // (module Discipline).
    private function statistiquesPresence(int $eleveId, PeriodeAcademique $periode): array
    {
        $absencesJustifiees = Absence::where('eleve_id', $eleveId)
            ->whereBetween('date_absence', [$periode->date_debut, $periode->date_fin])
            ->where('justifiee', true)
            ->count();

        $absencesNonJustifiees = Absence::where('eleve_id', $eleveId)
            ->whereBetween('date_absence', [$periode->date_debut, $periode->date_fin])
            ->where('justifiee', false)
            ->count();

        $retards = Sanction::where('eleve_id', $eleveId)
            ->where('type', 'retard')
            ->whereBetween('date_sanction', [$periode->date_debut, $periode->date_fin])
            ->count();

        return [$absencesJustifiees, $absencesNonJustifiees, $retards];
    }
}
