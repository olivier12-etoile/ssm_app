<?php

namespace App\Services;

use App\Models\Classe;
use App\Models\Eleve;
use App\Models\Matiere;
use App\Models\Note;
use App\Models\PeriodeAcademique;
use App\Models\User;
use Illuminate\Support\Collection;

/**
 * Statistiques pédagogiques ventilées par matière, enseignant et classe,
 * plus classements et listes d'alerte. Réutilise NoteCalculService pour
 * tout ce qui touche à la moyenne pondérée d'un élève (moyenneEleve), seule
 * source de vérité pour ce calcul dans l'application.
 */
class StatistiquePedagogiqueService
{
    public function __construct(private NoteCalculService $noteCalcul)
    {
    }

    // Pour chaque matière : moyenne générale (toutes classes), meilleure/
    // plus faible note, taux de réussite (part des élèves dont la moyenne
    // devoir+composition dans la matière est >= 10).
    public function parMatiere(int $ecoleId, int $periodeId): array
    {
        $periode = $this->periodeEcole($ecoleId, $periodeId);

        return Matiere::where('ecole_id', $ecoleId)
            ->orderBy('nom')
            ->get()
            ->map(function (Matiere $matiere) use ($periode) {
                $notes = Note::where('matiere_id', $matiere->id)
                    ->where('periode_id', $periode->id)
                    ->get();

                if ($notes->isEmpty()) {
                    return [
                        'matiere_id'       => $matiere->id,
                        'matiere_nom'      => $matiere->nom,
                        'moyenne_generale' => null,
                        'meilleure_note'   => null,
                        'plus_faible_note' => null,
                        'taux_reussite'    => 0.0,
                    ];
                }

                $moyennesEleves = $notes->pluck('eleve_id')->unique()
                    ->map(fn ($eleveId) => $this->detailMatiereEleve((int) $eleveId, $matiere->id, $periode->id))
                    ->filter(fn ($m) => $m !== null);

                return [
                    'matiere_id'       => $matiere->id,
                    'matiere_nom'      => $matiere->nom,
                    'moyenne_generale' => round((float) $notes->avg('valeur'), 2),
                    'meilleure_note'   => (float) $notes->max('valeur'),
                    'plus_faible_note' => (float) $notes->min('valeur'),
                    'taux_reussite'    => $moyennesEleves->isNotEmpty()
                        ? round($moyennesEleves->filter(fn ($m) => $m >= 10)->count() / $moyennesEleves->count() * 100, 1)
                        : 0.0,
                ];
            })
            ->values()
            ->all();
    }

    // Pour chaque enseignant : nb notes saisies, nb classes enseignées,
    // moyenne (brute) des notes saisies dans ses classes.
    public function parEnseignant(int $ecoleId, int $periodeId): array
    {
        $periode = $this->periodeEcole($ecoleId, $periodeId);

        return User::where('ecole_id', $ecoleId)
            ->where('role', 'enseignant')
            ->orderBy('name')
            ->get()
            ->map(function (User $enseignant) use ($periode) {
                $notes = Note::where('saisi_par', $enseignant->id)
                    ->where('periode_id', $periode->id)
                    ->get();

                $classesIds = $notes->pluck('classe_id')->unique();

                $moyennesClasses = $classesIds
                    ->map(fn ($classeId) => $notes->where('classe_id', $classeId)->avg('valeur'))
                    ->filter(fn ($m) => $m !== null);

                return [
                    'enseignant_id'   => $enseignant->id,
                    'enseignant_nom'  => $enseignant->name,
                    'notes_saisies'   => $notes->count(),
                    'nombre_classes'  => $classesIds->count(),
                    'moyenne_classes' => $moyennesClasses->isNotEmpty() ? round((float) $moyennesClasses->avg(), 2) : null,
                ];
            })
            ->values()
            ->all();
    }

    // Pour chaque classe : moyenne générale, meilleur/dernier élève, taux de réussite.
    public function parClasse(int $ecoleId, int $periodeId): array
    {
        $periode = $this->periodeEcole($ecoleId, $periodeId);

        return Classe::where('ecole_id', $ecoleId)
            ->where('annee_academique_id', $periode->annee_academique_id)
            ->orderBy('nom')
            ->get()
            ->map(fn (Classe $classe) => $this->statistiquesClasse($classe, $periode))
            ->values()
            ->all();
    }

    // Classement des classes par moyenne générale décroissante.
    public function meilleuresClasses(int $ecoleId, int $periodeId, int $limite = 10): array
    {
        return collect($this->parClasse($ecoleId, $periodeId))
            ->filter(fn ($c) => $c['moyenne_generale'] !== null)
            ->sortByDesc('moyenne_generale')
            ->take($limite)
            ->values()
            ->all();
    }

    // Top élèves de l'établissement (moyenne générale pondérée), filtrable par niveau.
    public function meilleursEleves(int $ecoleId, int $periodeId, int $limite = 10, ?string $niveau = null): array
    {
        $periode = $this->periodeEcole($ecoleId, $periodeId);

        $classes = Classe::where('ecole_id', $ecoleId)
            ->where('annee_academique_id', $periode->annee_academique_id)
            ->when($niveau, fn ($q) => $q->where('niveau', $niveau))
            ->get();

        $resultat = collect();

        foreach ($classes as $classe) {
            foreach ($this->elevesClasse($classe, $periode) as $eleve) {
                $moyenne = $this->noteCalcul->moyenneEleve($eleve->id, $periode->id);
                if ($moyenne === null) {
                    continue;
                }

                $resultat->push([
                    'eleve_id'         => $eleve->id,
                    'nom'              => $eleve->nom,
                    'prenom'           => $eleve->prenom,
                    'matricule'        => $eleve->matricule,
                    'classe_id'        => $classe->id,
                    'classe_nom'       => $classe->nom,
                    'niveau'           => $classe->niveau,
                    'moyenne_generale' => $moyenne,
                ]);
            }
        }

        return $resultat->sortByDesc('moyenne_generale')->take($limite)->values()->all();
    }

    // Élèves dont la moyenne générale pondérée est sous le seuil.
    public function elevesEnDifficulte(int $ecoleId, int $periodeId, float $seuil = 8): array
    {
        $periode = $this->periodeEcole($ecoleId, $periodeId);

        $classes = Classe::where('ecole_id', $ecoleId)
            ->where('annee_academique_id', $periode->annee_academique_id)
            ->get();

        $resultat = collect();

        foreach ($classes as $classe) {
            foreach ($this->elevesClasse($classe, $periode) as $eleve) {
                $moyenne = $this->noteCalcul->moyenneEleve($eleve->id, $periode->id);
                if ($moyenne === null || $moyenne >= $seuil) {
                    continue;
                }

                $resultat->push([
                    'eleve_id'         => $eleve->id,
                    'nom'              => $eleve->nom,
                    'prenom'           => $eleve->prenom,
                    'matricule'        => $eleve->matricule,
                    'classe_id'        => $classe->id,
                    'classe_nom'       => $classe->nom,
                    'moyenne_generale' => $moyenne,
                ]);
            }
        }

        return $resultat->sortBy('moyenne_generale')->values()->all();
    }

    // ── Aides internes ────────────────────────────────────────────

    private function statistiquesClasse(Classe $classe, PeriodeAcademique $periode): array
    {
        $eleves = $this->elevesClasse($classe, $periode);

        $moyennes = $eleves
            ->mapWithKeys(fn (Eleve $e) => [$e->id => $this->noteCalcul->moyenneEleve($e->id, $periode->id)])
            ->filter(fn ($m) => $m !== null);

        $meilleurId = $moyennes->sortDesc()->keys()->first();
        $dernierId = $moyennes->sort()->keys()->first();

        return [
            'classe_id'        => $classe->id,
            'classe_nom'       => $classe->nom,
            'nombre_eleves'    => $moyennes->count(),
            'moyenne_generale' => $moyennes->isNotEmpty() ? round($moyennes->avg(), 2) : null,
            'meilleur_eleve'   => $meilleurId ? $this->formaterEleve($eleves->firstWhere('id', $meilleurId), $moyennes[$meilleurId]) : null,
            'dernier_eleve'    => $dernierId ? $this->formaterEleve($eleves->firstWhere('id', $dernierId), $moyennes[$dernierId]) : null,
            'taux_reussite'    => $moyennes->isNotEmpty()
                ? round($moyennes->filter(fn ($m) => $m >= 10)->count() / $moyennes->count() * 100, 1)
                : 0.0,
        ];
    }

    private function formaterEleve(Eleve $eleve, float $moyenne): array
    {
        return [
            'eleve_id' => $eleve->id,
            'nom'      => $eleve->nom,
            'prenom'   => $eleve->prenom,
            'moyenne'  => $moyenne,
        ];
    }

    private function elevesClasse(Classe $classe, PeriodeAcademique $periode): Collection
    {
        return Eleve::where('ecole_id', $classe->ecole_id)
            ->whereHas('inscriptions', fn ($q) => $q
                ->where('classe_id', $classe->id)
                ->where('annee_academique_id', $periode->annee_academique_id))
            ->get();
    }

    // Moyenne de matière d'un élève (devoir + composition), dupliquée depuis
    // la logique privée de NoteCalculService::detailMatiereEleve() car ce
    // module a besoin de la moyenne PAR ÉLÈVE toutes classes confondues
    // (NoteCalculService::tauxReussite() est scopé à une seule classe). La
    // formule elle-même reste centralisée dans MoyenneCalculService.
    private function detailMatiereEleve(int $eleveId, int $matiereId, int $periodeId): ?float
    {
        $notes = Note::where('eleve_id', $eleveId)
            ->where('matiere_id', $matiereId)
            ->where('periode_id', $periodeId)
            ->get();

        $devoir = $notes->firstWhere('type_evaluation', 'devoir');
        $composition = $notes->firstWhere('type_evaluation', 'composition');

        return MoyenneCalculService::moyenneFinale(
            $devoir ? [(float) $devoir->valeur] : [],
            $composition?->valeur
        );
    }

    private function periodeEcole(int $ecoleId, int $periodeId): PeriodeAcademique
    {
        return PeriodeAcademique::whereHas('annee', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->with('annee')
            ->findOrFail($periodeId);
    }
}
