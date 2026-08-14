<?php

namespace App\Services;

use App\Models\AnneeAcademique;
use App\Models\Eleve;
use App\Models\FraisScolaire;
use Carbon\Carbon;

/**
 * Calcule le statut financier "badge" d'un élève (en_regle / partiel /
 * non_regle / en_retard), à afficher dans les listes et fiches élève.
 *
 * S'appuie entièrement sur FraisCalculService pour les montants dus/payés
 * (jamais de recalcul manuel), et n'ajoute que la logique propre au badge :
 * la détection d'échéances dépassées.
 */
class SituationFinanciereEleveService
{
    public function __construct(private FraisCalculService $fraisCalcul)
    {
    }

    // Statut financier de l'élève sur l'année scolaire donnée (l'année
    // active de l'école par défaut). "en_retard" est prioritaire sur tous
    // les autres statuts.
    public function statutFinancier(int $eleveId, ?int $anneeScolaireId = null): array
    {
        $eleve = Eleve::findOrFail($eleveId);

        $annee = $anneeScolaireId
            ? AnneeAcademique::where('ecole_id', $eleve->ecole_id)->find($anneeScolaireId)
            : AnneeAcademique::where('ecole_id', $eleve->ecole_id)->where('statut', 'active')->first();

        if (!$annee) {
            return [
                'statut'              => 'non_regle',
                'montant_du'          => 0.0,
                'montant_paye'        => 0.0,
                'reste_a_payer'       => 0.0,
                'echeances_en_retard' => [],
            ];
        }

        $situation = $this->fraisCalcul->situationEleve($eleve, $annee->id);
        $echeancesEnRetard = $this->echeancesEnRetard($eleve, $annee->id);

        $statut = match (true) {
            !empty($echeancesEnRetard) => 'en_retard',
            $situation['montant_paye'] <= 0 && $situation['montant_attendu'] > 0 => 'non_regle',
            $situation['reste_a_payer'] <= 0 => 'en_regle',
            default => 'partiel',
        };

        return [
            'statut'              => $statut,
            'montant_du'          => $situation['montant_attendu'],
            'montant_paye'        => $situation['montant_paye'],
            'reste_a_payer'       => $situation['reste_a_payer'],
            'echeances_en_retard' => $echeancesEnRetard,
        ];
    }

    // Échéances dont la date limite est dépassée et qui ne sont pas
    // entièrement soldées. Les paiements sont imputés aux échéances dans
    // l'ordre (la plus ancienne d'abord), comme un échéancier classique,
    // quel que soit l'echeance_id réellement renseigné sur le paiement.
    // Pour un frais sans échéances, on compare directement à sa date_limite.
    private function echeancesEnRetard(Eleve $eleve, int $anneeScolaireId): array
    {
        $aujourdHui = now()->startOfDay();
        $resultat = [];

        foreach ($this->fraisCalcul->fraisApplicables($eleve, $anneeScolaireId) as $frais) {
            /** @var FraisScolaire $frais */
            $echeances = $frais->echeances;

            if ($echeances->isEmpty()) {
                $reste = $this->fraisCalcul->resteAPayer($eleve, $frais);

                if ($frais->date_limite->lt($aujourdHui) && $reste > 0.01) {
                    $resultat[] = [
                        'frais_scolaire_id' => $frais->id,
                        'frais_nom'         => $frais->nom,
                        'echeance_id'       => null,
                        'libelle'           => $frais->nom,
                        'date_limite'       => $frais->date_limite,
                        'reste_a_payer'     => $reste,
                    ];
                }

                continue;
            }

            $totalPaye = $this->fraisCalcul->montantPayeParEleve($eleve, $frais);
            $cumulAlloue = 0.0;

            foreach ($echeances as $echeance) {
                $montantEcheance = (float) $echeance->montant;
                $alloueACetteEcheance = min(max($totalPaye - $cumulAlloue, 0), $montantEcheance);
                $cumulAlloue += $alloueACetteEcheance;
                $reste = round($montantEcheance - $alloueACetteEcheance, 2);

                if (Carbon::parse($echeance->date_limite)->lt($aujourdHui) && $reste > 0.01) {
                    $resultat[] = [
                        'frais_scolaire_id' => $frais->id,
                        'frais_nom'         => $frais->nom,
                        'echeance_id'       => $echeance->id,
                        'libelle'           => $echeance->libelle,
                        'date_limite'       => $echeance->date_limite,
                        'reste_a_payer'     => $reste,
                    ];
                }
            }
        }

        return $resultat;
    }
}
