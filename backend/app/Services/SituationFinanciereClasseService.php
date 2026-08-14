<?php

namespace App\Services;

use App\Models\AnneeAcademique;
use App\Models\Classe;
use App\Models\Eleve;

/**
 * Agrège la situation financière au niveau classe/école, à partir des
 * statuts individuels calculés par SituationFinanciereEleveService (jamais
 * de recalcul manuel des seuils en_regle/partiel/non_regle/en_retard ici).
 */
class SituationFinanciereClasseService
{
    public function __construct(
        private SituationFinanciereEleveService $situationEleve,
        private StatistiquePaiementService $statistiquePaiement
    ) {
    }

    // Situation agrégée d'une classe pour une année scolaire donnée.
    public function parClasse(int $classeId, int $anneeScolaireId): array
    {
        $classe = Classe::findOrFail($classeId);

        $eleves = Eleve::where('ecole_id', $classe->ecole_id)
            ->whereHas('inscriptions', fn ($q) => $q->where('annee_academique_id', $anneeScolaireId)->where('classe_id', $classeId))
            ->get();

        $statuts = $eleves->map(fn (Eleve $eleve) => $this->situationEleve->statutFinancier($eleve->id, $anneeScolaireId));

        $montantAttendu = round($statuts->sum('montant_du'), 2);
        $montantEncaisse = round($statuts->sum('montant_paye'), 2);

        return [
            'classe_id'          => $classe->id,
            'classe_nom'         => $classe->nom,
            'annee_scolaire_id'  => $anneeScolaireId,
            'nombre_eleves'      => $eleves->count(),
            'nombre_en_regle'    => $statuts->where('statut', 'en_regle')->count(),
            'nombre_partiel'     => $statuts->where('statut', 'partiel')->count(),
            'nombre_non_regle'   => $statuts->where('statut', 'non_regle')->count(),
            'nombre_en_retard'   => $statuts->where('statut', 'en_retard')->count(),
            'montant_attendu'    => $montantAttendu,
            'montant_encaisse'   => $montantEncaisse,
            'reste_a_recouvrer'  => round($montantAttendu - $montantEncaisse, 2),
            'taux_recouvrement'  => $montantAttendu > 0 ? round($montantEncaisse / $montantAttendu * 100, 1) : 0.0,
        ];
    }

    // parClasse() appliqué à toutes les classes de l'école rattachées à
    // cette année scolaire, triées par reste à recouvrer décroissant.
    public function toutesLesClasses(int $anneeScolaireId): array
    {
        $annee = AnneeAcademique::findOrFail($anneeScolaireId);

        $classes = Classe::where('ecole_id', $annee->ecole_id)
            ->where('annee_academique_id', $anneeScolaireId)
            ->orderBy('nom')
            ->get();

        return $classes
            ->map(fn (Classe $c) => $this->parClasse($c->id, $anneeScolaireId))
            ->sortByDesc('reste_a_recouvrer')
            ->values()
            ->all();
    }

    // Élèves non en règle de la classe, sur l'année scolaire active de
    // l'école — réutilise StatistiquePaiementService::elevesNonEnRegleListe()
    // plutôt que de recalculer les montants.
    public function impayesParClasse(int $classeId): array
    {
        $classe = Classe::findOrFail($classeId);

        $annee = AnneeAcademique::where('ecole_id', $classe->ecole_id)
            ->where('statut', 'active')
            ->first();

        if (!$annee) {
            return [];
        }

        return $this->statistiquePaiement->elevesNonEnRegleListe($annee, $classeId);
    }
}
