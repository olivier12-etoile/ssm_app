<?php

namespace App\Services;

use App\Models\AnneeAcademique;
use App\Models\Classe;
use App\Models\Inscription;
use App\Models\InstantaneStatistique;

/**
 * Statistiques d'inscriptions (effectifs) du module Élèves, ventilées par
 * année, niveau, classe et sexe. S'appuie sur StatistiqueGeneraleService
 * pour l'historique (instantanes_statistiques) et sur les mêmes tables
 * (inscriptions, classes, eleves) que le reste de l'application.
 */
class StatistiqueInscriptionService
{
    public function __construct(private StatistiqueGeneraleService $statistiqueGenerale)
    {
    }

    // Évolution des effectifs sur toutes les années scolaires de l'école
    // (dernier instantané "effectifs" enregistré pour chaque année, sinon
    // calcul à la volée).
    public function parAnnee(int $ecoleId): array
    {
        $annees = AnneeAcademique::where('ecole_id', $ecoleId)->orderBy('date_debut')->get();

        return $annees
            ->map(fn (AnneeAcademique $annee) => array_merge(
                ['annee_scolaire_id' => $annee->id, 'annee_libelle' => $annee->libelle],
                $this->donneesEffectifs($annee)
            ))
            ->values()
            ->all();
    }

    // Répartition des élèves inscrits par niveau (6ème, 5ème... selon les
    // classes réellement créées, pas d'enum figé).
    public function parNiveau(int $ecoleId, int $anneeScolaireId): array
    {
        $annee = $this->anneeEcole($ecoleId, $anneeScolaireId);

        return Classe::where('ecole_id', $annee->ecole_id)
            ->where('annee_academique_id', $annee->id)
            ->withCount('inscriptions')
            ->get()
            ->groupBy('niveau')
            ->map(fn ($classes, $niveau) => [
                'niveau'         => $niveau,
                'total_eleves'   => $classes->sum('inscriptions_count'),
                'nombre_classes' => $classes->count(),
            ])
            ->values()
            ->all();
    }

    // Répartition des élèves inscrits par classe.
    public function parClasse(int $ecoleId, int $anneeScolaireId): array
    {
        $annee = $this->anneeEcole($ecoleId, $anneeScolaireId);

        return Classe::where('ecole_id', $annee->ecole_id)
            ->where('annee_academique_id', $annee->id)
            ->withCount('inscriptions')
            ->orderBy('nom')
            ->get()
            ->map(fn (Classe $c) => [
                'classe_id'    => $c->id,
                'classe_nom'   => $c->nom,
                'niveau'       => $c->niveau,
                'effectif'     => $c->inscriptions_count,
                'capacite_max' => $c->capacite_max,
            ])
            ->all();
    }

    // Répartition garçons/filles, globale et par niveau.
    public function parSexe(int $ecoleId, int $anneeScolaireId): array
    {
        $annee = $this->anneeEcole($ecoleId, $anneeScolaireId);

        $inscriptions = Inscription::where('annee_academique_id', $annee->id)
            ->whereHas('eleve', fn ($q) => $q->where('ecole_id', $annee->ecole_id))
            ->with(['eleve:id,sexe', 'classe:id,niveau'])
            ->get();

        $parNiveau = $inscriptions
            ->groupBy(fn ($i) => $i->classe?->niveau ?? 'Non affecté')
            ->map(fn ($groupe, $niveau) => [
                'niveau'  => $niveau,
                'garcons' => $groupe->filter(fn ($i) => $i->eleve?->sexe === 'M')->count(),
                'filles'  => $groupe->filter(fn ($i) => $i->eleve?->sexe === 'F')->count(),
            ])
            ->values();

        return [
            'annee_scolaire_id' => $annee->id,
            'global'            => [
                'garcons' => $inscriptions->filter(fn ($i) => $i->eleve?->sexe === 'M')->count(),
                'filles'  => $inscriptions->filter(fn ($i) => $i->eleve?->sexe === 'F')->count(),
            ],
            'par_niveau' => $parNiveau->all(),
        ];
    }

    // Évolution du total des effectifs sur les N dernières années scolaires,
    // au format labels/valeurs prêt pour un graphique.
    public function evolutionEffectifs(int $ecoleId, int $nombreAnnees = 5): array
    {
        $annees = AnneeAcademique::where('ecole_id', $ecoleId)
            ->orderByDesc('date_debut')
            ->take($nombreAnnees)
            ->get()
            ->sortBy('date_debut')
            ->values();

        $detail = $annees->map(fn (AnneeAcademique $annee) => array_merge(
            ['annee_scolaire_id' => $annee->id, 'annee_libelle' => $annee->libelle],
            $this->donneesEffectifs($annee)
        ));

        return [
            'labels'  => $detail->pluck('annee_libelle')->all(),
            'valeurs' => $detail->pluck('total')->all(),
            'detail'  => $detail->values()->all(),
        ];
    }

    private function donneesEffectifs(AnneeAcademique $annee): array
    {
        $snapshot = InstantaneStatistique::where('annee_scolaire_id', $annee->id)
            ->where('type', 'effectifs')
            ->orderByDesc('date_snapshot')
            ->first();

        return $snapshot ? $snapshot->donnees : $this->statistiqueGenerale->effectifsGeneraux($annee->id);
    }

    private function anneeEcole(int $ecoleId, int $anneeScolaireId): AnneeAcademique
    {
        return AnneeAcademique::where('ecole_id', $ecoleId)->findOrFail($anneeScolaireId);
    }
}
