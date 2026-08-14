<?php

namespace App\Services;

use App\Models\AnneeAcademique;
use App\Models\Ecole;
use App\Models\PeriodeAcademique;
use Barryvdh\DomPDF\Facade\Pdf;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

/**
 * Génère les rapports téléchargeables (PDF ou Excel) du module Statistiques.
 * Ne recalcule jamais rien : chaque méthode assemble uniquement les données
 * déjà produites par StatistiqueGeneraleService / StatistiqueInscriptionService /
 * StatistiquePaiementService / StatistiquePedagogiqueService / FraisCalculService.
 *
 * Note : le projet a phpoffice/phpspreadsheet installé (pas maatwebsite/excel),
 * et c'est déjà ce que DashboardFraisController/ExportNoteController utilisent
 * pour les exports Excel — on reste cohérent avec ce choix existant.
 */
class RapportStatistiqueService
{
    public function __construct(
        private StatistiqueGeneraleService $statistiqueGenerale,
        private StatistiqueInscriptionService $statistiqueInscription,
        private StatistiquePaiementService $statistiquePaiement,
        private StatistiquePedagogiqueService $statistiquePedagogique,
        private FraisCalculService $fraisCalcul,
    ) {
    }

    // ── Rapport d'inscriptions ──────────────────────────────────────
    public function rapportInscriptions(int $ecoleId, int $anneeScolaireId, string $format = 'pdf')
    {
        $annee = AnneeAcademique::where('ecole_id', $ecoleId)->findOrFail($anneeScolaireId);

        $effectifs = $this->statistiqueGenerale->effectifsGeneraux($anneeScolaireId);
        $parNiveau = $this->statistiqueInscription->parNiveau($ecoleId, $anneeScolaireId);
        $parClasse = $this->statistiqueInscription->parClasse($ecoleId, $anneeScolaireId);
        $parSexe = $this->statistiqueInscription->parSexe($ecoleId, $anneeScolaireId);

        $sections = [
            [
                'titre' => 'Effectifs généraux',
                'colonnes' => ['Indicateur', 'Valeur'],
                'lignes' => [
                    ['Total élèves', $effectifs['total']],
                    ['Garçons', $effectifs['garcons']],
                    ['Filles', $effectifs['filles']],
                    ['Nouveaux inscrits', $effectifs['nouveaux_inscrits']],
                    ['Réinscriptions', $effectifs['reinscriptions']],
                    ['Transférés', $effectifs['transferes']],
                    ['Renvoyés', $effectifs['renvoyes']],
                    ['Abandons', $effectifs['abandons']],
                ],
            ],
            [
                'titre' => 'Répartition par niveau',
                'colonnes' => ['Niveau', 'Nombre de classes', 'Total élèves'],
                'lignes' => collect($parNiveau)
                    ->map(fn ($n) => [$n['niveau'], $n['nombre_classes'], $n['total_eleves']])
                    ->all(),
            ],
            [
                'titre' => 'Répartition par classe',
                'colonnes' => ['Classe', 'Niveau', 'Effectif', 'Capacité max'],
                'lignes' => collect($parClasse)
                    ->map(fn ($c) => [$c['classe_nom'], $c['niveau'], $c['effectif'], $c['capacite_max']])
                    ->all(),
            ],
            [
                'titre' => 'Répartition par sexe et niveau',
                'colonnes' => ['Niveau', 'Garçons', 'Filles'],
                'lignes' => array_merge(
                    collect($parSexe['par_niveau'])->map(fn ($n) => [$n['niveau'], $n['garcons'], $n['filles']])->all(),
                    [['Total école', $parSexe['global']['garcons'], $parSexe['global']['filles']]]
                ),
            ],
        ];

        return $this->genererDocument(
            $annee->ecole,
            "RAPPORT D'INSCRIPTIONS",
            "Année scolaire {$annee->libelle}",
            $sections,
            'rapport_inscriptions_' . $this->nomFichierSur($annee->libelle),
            $format
        );
    }

    // ── Rapport financier (résumé + débiteurs) ──────────────────────
    public function rapportFinancier(int $ecoleId, int $anneeScolaireId, string $format = 'pdf')
    {
        $annee = AnneeAcademique::where('ecole_id', $ecoleId)->findOrFail($anneeScolaireId);

        $resume = $this->statistiqueGenerale->resumeFinancier($anneeScolaireId);
        $rapportDetail = $this->fraisCalcul->rapportEcole($ecoleId, $anneeScolaireId);

        $sections = [
            [
                'titre' => 'Résumé financier',
                'colonnes' => ['Indicateur', 'Valeur'],
                'lignes' => [
                    ['Montant attendu', $resume['montant_attendu']],
                    ['Montant encaissé', $resume['montant_encaisse']],
                    ['Montant restant', $resume['montant_restant']],
                    ['Taux de recouvrement', $resume['taux_recouvrement'] . ' %'],
                    ['Nombre de débiteurs', $resume['nombre_debiteurs']],
                ],
            ],
            [
                'titre' => 'Élèves débiteurs',
                'colonnes' => ['Nom', 'Classe', 'Montant dû', 'Montant payé', 'Reste à payer'],
                'lignes' => collect($rapportDetail['debiteurs'])
                    ->map(fn ($d) => [
                        $d['nom'] . ' ' . $d['prenom'],
                        $d['classe_nom'],
                        $d['montant_du'],
                        $d['montant_paye'],
                        $d['montant_restant'],
                    ])
                    ->all(),
            ],
        ];

        return $this->genererDocument(
            $annee->ecole,
            'RAPPORT FINANCIER',
            "Année scolaire {$annee->libelle}",
            $sections,
            'rapport_financier_' . $this->nomFichierSur($annee->libelle),
            $format
        );
    }

    // ── Rapport détaillé des paiements ──────────────────────────────
    public function rapportPaiements(int $ecoleId, int $anneeScolaireId, string $format = 'pdf')
    {
        $annee = AnneeAcademique::where('ecole_id', $ecoleId)->findOrFail($anneeScolaireId);

        $parClasse = $this->statistiquePaiement->parClasse($ecoleId, $anneeScolaireId);
        $parNiveau = $this->statistiquePaiement->parNiveau($ecoleId, $anneeScolaireId);
        $parMois = $this->statistiquePaiement->parMois($ecoleId, $anneeScolaireId);

        $sections = [
            [
                'titre' => 'Paiements par classe',
                'colonnes' => ['Classe', 'Élèves à jour', 'Élèves en retard', 'Montant attendu', 'Montant encaissé', 'Taux recouvrement'],
                'lignes' => collect($parClasse)
                    ->map(fn ($c) => [
                        $c['classe_nom'], $c['eleves_a_jour'], $c['eleves_en_retard'],
                        $c['montant_attendu'], $c['montant_encaisse'], $c['taux_recouvrement'] . ' %',
                    ])
                    ->all(),
            ],
            [
                'titre' => 'Paiements par niveau',
                'colonnes' => ['Niveau', 'Élèves à jour', 'Élèves en retard', 'Montant attendu', 'Montant encaissé', 'Taux recouvrement'],
                'lignes' => collect($parNiveau)
                    ->map(fn ($n) => [
                        $n['niveau'], $n['eleves_a_jour'], $n['eleves_en_retard'],
                        $n['montant_attendu'], $n['montant_encaisse'], $n['taux_recouvrement'] . ' %',
                    ])
                    ->all(),
            ],
            [
                'titre' => 'Recettes par mois',
                'colonnes' => ['Mois', 'Montant encaissé'],
                'lignes' => collect($parMois)->map(fn ($m) => [$m['libelle'], $m['montant']])->all(),
            ],
        ];

        return $this->genererDocument(
            $annee->ecole,
            'RAPPORT DES PAIEMENTS',
            "Année scolaire {$annee->libelle}",
            $sections,
            'rapport_paiements_' . $this->nomFichierSur($annee->libelle),
            $format
        );
    }

    // ── Rapport des résultats scolaires ──────────────────────────────
    public function rapportResultats(int $ecoleId, int $anneeScolaireId, int $periodeId, string $format = 'pdf')
    {
        $annee = AnneeAcademique::where('ecole_id', $ecoleId)->findOrFail($anneeScolaireId);
        $periode = PeriodeAcademique::where('annee_academique_id', $annee->id)->findOrFail($periodeId);

        $resume = $this->statistiqueGenerale->resumeResultatsScolaires($anneeScolaireId, $periodeId);
        $parClasse = $this->statistiquePedagogique->parClasse($ecoleId, $periodeId);
        $parMatiere = $this->statistiquePedagogique->parMatiere($ecoleId, $periodeId);

        $sections = [
            [
                'titre' => 'Résumé des résultats scolaires',
                'colonnes' => ['Indicateur', 'Valeur'],
                'lignes' => [
                    ['Moyenne générale école', $resume['moyenne_generale']],
                    ['Taux de réussite', $resume['taux_reussite'] . ' %'],
                    ["Taux d'échec", $resume['taux_echec'] . ' %'],
                    ['Élèves >= 10/20', $resume['nombre_eleves_ge_10']],
                    ['Élèves < 10/20', $resume['nombre_eleves_lt_10']],
                ],
            ],
            [
                'titre' => 'Résultats par classe',
                'colonnes' => ['Classe', 'Nb élèves', 'Moyenne', 'Meilleur élève', 'Dernier élève', 'Taux réussite'],
                'lignes' => collect($parClasse)
                    ->map(fn ($c) => [
                        $c['classe_nom'],
                        $c['nombre_eleves'],
                        $c['moyenne_generale'],
                        $this->formaterEleveLigne($c['meilleur_eleve']),
                        $this->formaterEleveLigne($c['dernier_eleve']),
                        $c['taux_reussite'] . ' %',
                    ])
                    ->all(),
            ],
            [
                'titre' => 'Résultats par matière',
                'colonnes' => ['Matière', 'Moyenne', 'Meilleure note', 'Plus faible note', 'Taux réussite'],
                'lignes' => collect($parMatiere)
                    ->map(fn ($m) => [
                        $m['matiere_nom'], $m['moyenne_generale'], $m['meilleure_note'], $m['plus_faible_note'], $m['taux_reussite'] . ' %',
                    ])
                    ->all(),
            ],
        ];

        return $this->genererDocument(
            $annee->ecole,
            'RAPPORT DES RÉSULTATS SCOLAIRES',
            "Année scolaire {$annee->libelle} — {$periode->nom}",
            $sections,
            'rapport_resultats_' . $this->nomFichierSur($periode->nom),
            $format
        );
    }

    // ── Rapport des meilleurs élèves ─────────────────────────────────
    public function rapportMeilleursEleves(int $ecoleId, int $periodeId, int $limite = 10, string $format = 'pdf')
    {
        $periode = $this->periodeEcole($ecoleId, $periodeId);

        $eleves = $this->statistiquePedagogique->meilleursEleves($ecoleId, $periodeId, $limite);

        $sections = [[
            'titre' => 'Meilleurs élèves',
            'colonnes' => ['Rang', 'Nom', 'Prénom', 'Matricule', 'Classe', 'Moyenne générale'],
            'lignes' => collect($eleves)->values()
                ->map(fn ($e, $i) => [$i + 1, $e['nom'], $e['prenom'], $e['matricule'], $e['classe_nom'], $e['moyenne_generale']])
                ->all(),
        ]];

        return $this->genererDocument(
            $periode->annee->ecole,
            'MEILLEURS ÉLÈVES',
            "Période : {$periode->nom}",
            $sections,
            'meilleurs_eleves_' . $this->nomFichierSur($periode->nom),
            $format
        );
    }

    // ── Rapport des élèves en difficulté ─────────────────────────────
    public function rapportElevesEnDifficulte(int $ecoleId, int $periodeId, float $seuil = 8, string $format = 'pdf')
    {
        $periode = $this->periodeEcole($ecoleId, $periodeId);

        $eleves = $this->statistiquePedagogique->elevesEnDifficulte($ecoleId, $periodeId, $seuil);

        $sections = [[
            'titre' => "Élèves en difficulté (moyenne < {$seuil}/20)",
            'colonnes' => ['Nom', 'Prénom', 'Matricule', 'Classe', 'Moyenne générale'],
            'lignes' => collect($eleves)
                ->map(fn ($e) => [$e['nom'], $e['prenom'], $e['matricule'], $e['classe_nom'], $e['moyenne_generale']])
                ->all(),
        ]];

        return $this->genererDocument(
            $periode->annee->ecole,
            'ÉLÈVES EN DIFFICULTÉ',
            "Période : {$periode->nom} — Seuil : {$seuil}/20",
            $sections,
            'eleves_difficulte_' . $this->nomFichierSur($periode->nom),
            $format
        );
    }

    // ── Aides internes ────────────────────────────────────────────

    private function periodeEcole(int $ecoleId, int $periodeId): PeriodeAcademique
    {
        return PeriodeAcademique::whereHas('annee', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->with('annee.ecole')
            ->findOrFail($periodeId);
    }

    private function formaterEleveLigne(?array $eleve): string
    {
        return $eleve ? "{$eleve['nom']} {$eleve['prenom']} ({$eleve['moyenne']}/20)" : '—';
    }

    private function nomFichierSur(string $libelle): string
    {
        return str_replace([' ', '/', '\\'], '_', $libelle);
    }

    private function genererDocument(Ecole $ecole, string $titre, string $sousTitre, array $sections, string $nomFichier, string $format)
    {
        if ($format === 'excel') {
            return $this->genererExcel($sections, $nomFichier);
        }

        $pdf = Pdf::loadView('pdf.statistiques_rapport', [
            'ecole' => [
                'nom' => $ecole->nom,
                'code_ecole' => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'titre' => $titre,
            'sousTitre' => $sousTitre,
            'sections' => $sections,
            'genere_le' => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download($nomFichier . '.pdf');
    }

    private function genererExcel(array $sections, string $nomFichier)
    {
        $spreadsheet = new Spreadsheet();
        $premiere = true;

        foreach ($sections as $section) {
            $feuille = $premiere ? $spreadsheet->getActiveSheet() : $spreadsheet->createSheet();
            $premiere = false;

            $feuille->setTitle($this->nomFeuille($section['titre']));
            $feuille->fromArray($section['colonnes'], null, 'A1');

            $ligneIndex = 2;
            foreach ($section['lignes'] as $ligne) {
                $feuille->fromArray($ligne, null, "A{$ligneIndex}");
                $ligneIndex++;
            }
        }

        return $this->telechargerSpreadsheet($spreadsheet, $nomFichier . '.xlsx');
    }

    // Les noms de feuille Excel sont limités à 31 caractères et ne peuvent
    // pas contenir certains caractères spéciaux.
    private function nomFeuille(string $titre): string
    {
        $nettoye = preg_replace('/[\[\]\*\/\\\\\?:]/', '', $titre);

        return mb_substr($nettoye, 0, 31);
    }

    private function telechargerSpreadsheet(Spreadsheet $spreadsheet, string $nomFichier)
    {
        $dossierTemp = storage_path('app/tmp');
        if (!is_dir($dossierTemp)) {
            mkdir($dossierTemp, 0755, true);
        }
        $cheminTemp = $dossierTemp . '/' . $nomFichier;

        (new Xlsx($spreadsheet))->save($cheminTemp);

        return response()->download($cheminTemp, $nomFichier)->deleteFileAfterSend(true);
    }
}
