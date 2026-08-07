<?php

namespace App\Services;

use App\Models\Eleve;
use App\Models\ExonerationEleve;
use App\Models\FraisScolaire;
use App\Models\Inscription;
use App\Models\Paiement;
use App\Models\RemiseEleve;

/**
 * Centralise tous les calculs financiers du module Frais Scolaires, pour
 * garantir que les mêmes règles sont appliquées partout (contrôleurs,
 * rapports, exports).
 *
 * Règle importante : les paiements annulés (statut = annule) ne comptent
 * JAMAIS dans les totaux encaissés.
 *
 * Note sur les exonérations : le schéma de exonerations_eleves ne porte pas
 * de montant/pourcentage — seul le type 'totale' a un effet chiffrable (le
 * frais devient dû à 0). Le type 'partielle' est informatif ; la réduction
 * concrète doit être enregistrée via une RemiseEleve (type
 * remise_administrative) pour être prise en compte dans les calculs.
 */
class FraisCalculService
{
    // Montant de réduction (remises + exonération totale) applicable à un
    // élève sur un frais donné, plafonné au montant du frais.
    public function reductionApplicable(Eleve $eleve, FraisScolaire $frais): float
    {
        $exonerationTotale = ExonerationEleve::where('eleve_id', $eleve->id)
            ->where('frais_scolaire_id', $frais->id)
            ->where('type', 'totale')
            ->exists();

        if ($exonerationTotale) {
            return (float) $frais->montant;
        }

        $reduction = RemiseEleve::where('eleve_id', $eleve->id)
            ->where('frais_scolaire_id', $frais->id)
            ->get()
            ->sum(function (RemiseEleve $remise) use ($frais) {
                if ($remise->montant !== null) {
                    return (float) $remise->montant;
                }
                if ($remise->pourcentage !== null) {
                    return (float) $frais->montant * ((float) $remise->pourcentage / 100);
                }
                return 0.0;
            });

        return min($reduction, (float) $frais->montant);
    }

    // montantDuParEleve(eleve, frais) = frais.montant - remise applicable - exonération applicable
    public function montantDuParEleve(Eleve $eleve, FraisScolaire $frais): float
    {
        return round((float) $frais->montant - $this->reductionApplicable($eleve, $frais), 2);
    }

    // Somme des paiements VALIDES (jamais les annulés) de l'élève sur ce frais.
    public function montantPayeParEleve(Eleve $eleve, FraisScolaire $frais): float
    {
        return (float) Paiement::where('eleve_id', $eleve->id)
            ->where('frais_scolaire_id', $frais->id)
            ->where('statut', 'valide')
            ->sum('montant');
    }

    // resteAPayer(eleve, frais) = montantDu - somme(paiements valides)
    public function resteAPayer(Eleve $eleve, FraisScolaire $frais): float
    {
        return round($this->montantDuParEleve($eleve, $frais) - $this->montantPayeParEleve($eleve, $frais), 2);
    }

    public function statutFrais(float $montantDu, float $montantPaye): string
    {
        if ($montantDu <= 0 || $montantPaye >= $montantDu) {
            return 'paye';
        }
        if ($montantPaye > 0) {
            return 'partiel';
        }
        return 'impaye';
    }

    // Frais concernant un élève pour une année scolaire donnée, selon la
    // classe/série de son inscription (un frais sans classe_id/serie
    // s'applique à tout le monde).
    public function fraisApplicables(Eleve $eleve, int $anneeScolaireId)
    {
        $inscription = Inscription::where('eleve_id', $eleve->id)
            ->where('annee_academique_id', $anneeScolaireId)
            ->with('classe')
            ->first();

        $classeId = $inscription?->classe_id;
        $serie    = $inscription?->classe?->serie;

        return FraisScolaire::where('ecole_id', $eleve->ecole_id)
            ->where('annee_scolaire_id', $anneeScolaireId)
            ->where('actif', true)
            ->where(fn($q) => $q->whereNull('classe_id')->orWhere('classe_id', $classeId))
            ->where(fn($q) => $q->whereNull('serie')->orWhere('serie', $serie))
            ->orderBy('date_limite')
            ->get();
    }

    // Situation financière complète d'un élève pour une année scolaire.
    public function situationEleve(Eleve $eleve, int $anneeScolaireId): array
    {
        $frais = $this->fraisApplicables($eleve, $anneeScolaireId);

        $detail = $frais->map(function (FraisScolaire $f) use ($eleve) {
            $du   = $this->montantDuParEleve($eleve, $f);
            $paye = $this->montantPayeParEleve($eleve, $f);

            return [
                'frais_scolaire_id' => $f->id,
                'nom'               => $f->nom,
                'montant'           => (float) $f->montant,
                'date_limite'       => $f->date_limite,
                'montant_du'        => $du,
                'montant_paye'      => $paye,
                'reste_a_payer'     => round($du - $paye, 2),
                'statut'            => $this->statutFrais($du, $paye),
            ];
        })->values();

        return [
            'frais'           => $detail,
            'montant_attendu' => round($detail->sum('montant_du'), 2),
            'montant_paye'    => round($detail->sum('montant_paye'), 2),
            'reste_a_payer'   => round($detail->sum('reste_a_payer'), 2),
        ];
    }

    // Rapport financier global de l'école pour une année scolaire : totaux
    // attendu/encaissé et liste des élèves débiteurs (reste_a_payer > 0).
    // Remplace l'ancien FraisScolaireController::calculerRapportFinancier()
    // (basé sur l'ancien modèle classe+montant_total, disparu avec la refonte
    // du module Frais Scolaires).
    public function rapportEcole(int $ecoleId, int $anneeScolaireId): array
    {
        $eleves = Eleve::where('ecole_id', $ecoleId)
            ->whereHas('inscriptions', fn($q) => $q->where('annee_academique_id', $anneeScolaireId))
            ->with(['inscriptions' => fn($q) => $q->where('annee_academique_id', $anneeScolaireId)->with('classe')])
            ->get();

        $totalAttendu = 0;
        $totalEncaisse = 0;
        $debiteurs = [];

        foreach ($eleves as $eleve) {
            $classe = $eleve->inscriptions->first()?->classe;
            $situation = $this->situationEleve($eleve, $anneeScolaireId);

            $totalAttendu += $situation['montant_attendu'];
            $totalEncaisse += $situation['montant_paye'];

            if ($situation['reste_a_payer'] > 0) {
                $debiteurs[] = [
                    'eleve_id'        => $eleve->id,
                    'nom'             => $eleve->nom,
                    'prenom'          => $eleve->prenom,
                    'classe_id'       => $classe?->id,
                    'classe_nom'      => $classe?->nom,
                    'montant_du'      => $situation['montant_attendu'],
                    'montant_paye'    => $situation['montant_paye'],
                    'montant_restant' => $situation['reste_a_payer'],
                ];
            }
        }

        usort($debiteurs, fn($a, $b) => $b['montant_restant'] <=> $a['montant_restant']);

        return [
            'annee_scolaire_id' => $anneeScolaireId,
            'debiteurs'         => $debiteurs,
            'total_global'      => [
                'total_attendu'  => round($totalAttendu, 2),
                'total_encaisse' => round($totalEncaisse, 2),
                'total_restant'  => round($totalAttendu - $totalEncaisse, 2),
            ],
        ];
    }
}
