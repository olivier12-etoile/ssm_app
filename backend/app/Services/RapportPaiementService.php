<?php

namespace App\Services;

use App\Models\AnneeAcademique;
use App\Models\Eleve;
use App\Models\Paiement;
use Barryvdh\DomPDF\Facade\Pdf;
use Carbon\Carbon;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

/**
 * Rapports d'encaissement (journalier, hebdomadaire, mensuel, annuel,
 * personnalisé) pour le module Paiements, avec export PDF/Excel.
 *
 * Le "montant attendu"/"reste à recouvrer" reportés sont toujours calculés
 * sur l'année scolaire concernée dans son ensemble (via FraisCalculService),
 * jamais recalculés à la main ici — seul l'encaissé de la période demandée
 * est agrégé directement depuis les paiements.
 */
class RapportPaiementService
{
    private const MODES_PAIEMENT = [
        'especes'    => 'Espèces',
        'moov_money' => 'Moov Money',
        'wave'       => 'Wave',
        'virement'   => 'Virement',
        'cheque'     => 'Chèque',
    ];

    private const JOURS_FR = [
        1 => 'Lundi', 2 => 'Mardi', 3 => 'Mercredi', 4 => 'Jeudi',
        5 => 'Vendredi', 6 => 'Samedi', 7 => 'Dimanche',
    ];

    private const MOIS_FR = [
        1 => 'Janvier', 2 => 'Février', 3 => 'Mars', 4 => 'Avril',
        5 => 'Mai', 6 => 'Juin', 7 => 'Juillet', 8 => 'Août',
        9 => 'Septembre', 10 => 'Octobre', 11 => 'Novembre', 12 => 'Décembre',
    ];

    public function __construct(
        private FraisCalculService $fraisCalcul,
        private StatistiquePaiementService $statistiquePaiement
    ) {
    }

    // Paiements d'un jour précis, ventilés par mode de paiement.
    public function rapportJournalier(string $date): array
    {
        $jour = Carbon::parse($date);

        $paiements = Paiement::where('statut', 'valide')
            ->whereDate('date_paiement', $jour->toDateString())
            ->with(['eleve', 'fraisScolaire'])
            ->orderBy('id')
            ->get();

        return [
            'date'              => $jour->format('d/m/Y'),
            'nombre_paiements'  => $paiements->count(),
            'total_encaisse'    => round($paiements->sum('montant'), 2),
            'par_mode_paiement' => $this->ventilerParMode($paiements),
            'transactions'      => $paiements->map(fn (Paiement $p) => $this->formaterTransaction($p))->values()->all(),
        ];
    }

    // 7 jours à partir de dateDebut, avec comparaison jour par jour.
    public function rapportHebdomadaire(string $dateDebut): array
    {
        $debut = Carbon::parse($dateDebut)->startOfDay();
        $fin = $debut->copy()->addDays(6)->endOfDay();

        $paiements = Paiement::where('statut', 'valide')
            ->whereBetween('date_paiement', [$debut->toDateString(), $fin->toDateString()])
            ->get();

        $parJour = [];
        for ($i = 0; $i < 7; $i++) {
            $jour = $debut->copy()->addDays($i);
            $duJour = $paiements->filter(fn (Paiement $p) => Carbon::parse($p->date_paiement)->isSameDay($jour));

            $parJour[] = [
                'date'             => $jour->format('Y-m-d'),
                'libelle'          => self::JOURS_FR[$jour->dayOfWeekIso] . ' ' . $jour->format('d/m'),
                'nombre_paiements' => $duJour->count(),
                'total_encaisse'   => round($duJour->sum('montant'), 2),
            ];
        }

        return [
            'periode_libelle'   => 'Semaine du ' . $debut->format('d/m/Y'),
            'date_debut'        => $debut->format('d/m/Y'),
            'date_fin'          => $fin->format('d/m/Y'),
            'nombre_paiements'  => $paiements->count(),
            'total_encaisse_periode' => round($paiements->sum('montant'), 2),
            'par_mode_paiement' => $this->ventilerParMode($paiements),
            'par_jour'          => $parJour,
        ];
    }

    // Rapport du mois donné : attendu/encaissé/reste sur l'année scolaire
    // active, ventilés par mode et par classe pour les paiements du mois.
    public function rapportMensuel(int $mois, int $annee): array
    {
        $debut = Carbon::createFromDate($annee, $mois, 1)->startOfMonth();
        $fin = $debut->copy()->endOfMonth();

        return $this->rapportSurPeriode($debut, $fin, self::MOIS_FR[$mois] . ' ' . $annee);
    }

    // Rapport sur toute la durée d'une année scolaire, + évolution mois par mois.
    public function rapportAnnuel(int $anneeScolaireId): array
    {
        $annee = AnneeAcademique::findOrFail($anneeScolaireId);
        $debut = Carbon::parse($annee->date_debut)->startOfDay();
        $fin = Carbon::parse($annee->date_fin)->endOfDay();

        $rapport = $this->rapportSurPeriode($debut, $fin, $annee->libelle, $annee->id);
        $rapport['evolution_mensuelle'] = $this->statistiquePaiement->parMois($annee->ecole_id, $annee->id);

        return $rapport;
    }

    // Plage de dates libre.
    public function rapportPersonnalise(string $dateDebut, string $dateFin): array
    {
        $debut = Carbon::parse($dateDebut)->startOfDay();
        $fin = Carbon::parse($dateFin)->endOfDay();

        return $this->rapportSurPeriode($debut, $fin, $debut->format('d/m/Y') . ' au ' . $fin->format('d/m/Y'));
    }

    // Génère et télécharge le PDF correspondant au type de rapport demandé.
    public function exportPdf(string $typeRapport, array $parametres)
    {
        $donnees = $this->genererDonnees($typeRapport, $parametres);
        $ecole = auth()->user()->ecole;

        $pdf = Pdf::loadView('pdf.rapport_paiements', [
            'ecole' => [
                'nom'              => $ecole->nom,
                'code_ecole'       => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'type_rapport' => $typeRapport,
            'rapport'      => $donnees,
            'genere_le'    => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download('rapport_paiements_' . $typeRapport . '_' . now()->format('Ymd_His') . '.pdf');
    }

    // Génère et télécharge l'Excel correspondant au type de rapport demandé.
    public function exportExcel(string $typeRapport, array $parametres)
    {
        $donnees = $this->genererDonnees($typeRapport, $parametres);

        $spreadsheet = new Spreadsheet();
        $feuille = $spreadsheet->getActiveSheet();
        $feuille->setTitle('Rapport paiements');

        $ligne = 1;
        $feuille->setCellValue("A{$ligne}", 'Rapport de paiements — ' . ucfirst($typeRapport));
        $ligne += 2;

        if ($typeRapport === 'journalier') {
            $feuille->fromArray(['Date', $donnees['date']], null, "A{$ligne}");
            $ligne++;
        } else {
            $feuille->fromArray(['Période', $donnees['periode_libelle']], null, "A{$ligne}");
            $ligne++;
            $feuille->fromArray(['Du', $donnees['date_debut']], null, "A{$ligne}");
            $ligne++;
            $feuille->fromArray(['Au', $donnees['date_fin']], null, "A{$ligne}");
            $ligne++;
        }

        $feuille->fromArray(['Nombre de paiements', $donnees['nombre_paiements']], null, "A{$ligne}");
        $ligne++;
        $feuille->fromArray(['Total encaissé', $donnees['total_encaisse'] ?? $donnees['total_encaisse_periode']], null, "A{$ligne}");
        $ligne += 2;

        $feuille->fromArray(['Ventilation par mode de paiement'], null, "A{$ligne}");
        $ligne++;
        $feuille->fromArray(['Mode', 'Nombre', 'Montant'], null, "A{$ligne}");
        $ligne++;
        foreach ($donnees['par_mode_paiement'] as $m) {
            $feuille->fromArray([$m['libelle'], $m['nombre'], $m['montant']], null, "A{$ligne}");
            $ligne++;
        }
        $ligne++;

        if (isset($donnees['par_classe'])) {
            $feuille->fromArray(['Ventilation par classe'], null, "A{$ligne}");
            $ligne++;
            $feuille->fromArray(['Classe', 'Nombre', 'Montant'], null, "A{$ligne}");
            $ligne++;
            foreach ($donnees['par_classe'] as $c) {
                $feuille->fromArray([$c['classe_nom'], $c['nombre'], $c['montant']], null, "A{$ligne}");
                $ligne++;
            }
            $ligne++;
        }

        if (isset($donnees['par_jour'])) {
            $feuille->fromArray(['Détail par jour'], null, "A{$ligne}");
            $ligne++;
            $feuille->fromArray(['Jour', 'Nombre', 'Montant'], null, "A{$ligne}");
            $ligne++;
            foreach ($donnees['par_jour'] as $j) {
                $feuille->fromArray([$j['libelle'], $j['nombre_paiements'], $j['total_encaisse']], null, "A{$ligne}");
                $ligne++;
            }
            $ligne++;
        }

        if (isset($donnees['evolution_mensuelle'])) {
            $feuille->fromArray(['Évolution mensuelle'], null, "A{$ligne}");
            $ligne++;
            $feuille->fromArray(['Mois', 'Montant'], null, "A{$ligne}");
            $ligne++;
            foreach ($donnees['evolution_mensuelle'] as $m) {
                $feuille->fromArray([$m['libelle'], $m['montant']], null, "A{$ligne}");
                $ligne++;
            }
            $ligne++;
        }

        if (isset($donnees['transactions'])) {
            $feuille->fromArray(['N° Reçu', 'Élève', 'Frais', 'Mode', 'Montant', 'Date'], null, "A{$ligne}");
            $ligne++;
            foreach ($donnees['transactions'] as $t) {
                $feuille->fromArray([$t['numero_recu'], $t['eleve'], $t['frais_nom'], $t['mode_paiement'], $t['montant'], $t['date_paiement']], null, "A{$ligne}");
                $ligne++;
            }
        }

        $dossierTemp = storage_path('app/tmp');
        if (!is_dir($dossierTemp)) {
            mkdir($dossierTemp, 0755, true);
        }
        $nomFichier = 'rapport_paiements_' . $typeRapport . '_' . now()->format('Ymd_His') . '.xlsx';
        $cheminTemp = $dossierTemp . '/' . $nomFichier;

        (new Xlsx($spreadsheet))->save($cheminTemp);

        return response()->download($cheminTemp, $nomFichier)->deleteFileAfterSend(true);
    }

    // ── Aides internes ────────────────────────────────────────────

    private function genererDonnees(string $typeRapport, array $parametres): array
    {
        return match ($typeRapport) {
            'journalier'   => $this->rapportJournalier($parametres['date'] ?? now()->toDateString()),
            'hebdomadaire' => $this->rapportHebdomadaire($parametres['date_debut'] ?? now()->startOfWeek()->toDateString()),
            'mensuel'      => $this->rapportMensuel((int) ($parametres['mois'] ?? now()->month), (int) ($parametres['annee'] ?? now()->year)),
            'annuel'       => $this->rapportAnnuel((int) ($parametres['annee_scolaire_id'] ?? 0)),
            'personnalise' => $this->rapportPersonnalise($parametres['date_debut'], $parametres['date_fin']),
            default        => throw new \InvalidArgumentException("Type de rapport inconnu : {$typeRapport}"),
        };
    }

    // Rapport partagé par mensuel/annuel/personnalisé : encaissé de la
    // période + attendu/encaissé/reste sur l'année scolaire concernée.
    private function rapportSurPeriode(Carbon $debut, Carbon $fin, string $libellePeriode, ?int $anneeScolaireId = null): array
    {
        $ecoleId = auth()->user()->ecole_id;

        $annee = $anneeScolaireId
            ? AnneeAcademique::where('ecole_id', $ecoleId)->find($anneeScolaireId)
            : AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->first();

        $situationGlobale = $annee
            ? $this->situationGlobale($annee)
            : ['montant_attendu' => 0.0, 'montant_paye' => 0.0];

        $paiements = Paiement::where('statut', 'valide')
            ->whereBetween('date_paiement', [$debut->toDateString(), $fin->toDateString()])
            ->with(['eleve.inscriptions.classe', 'fraisScolaire'])
            ->orderBy('date_paiement')
            ->get();

        return [
            'periode_libelle'        => $libellePeriode,
            'date_debut'             => $debut->format('d/m/Y'),
            'date_fin'               => $fin->format('d/m/Y'),
            'nombre_paiements'       => $paiements->count(),
            'montant_attendu'        => $situationGlobale['montant_attendu'],
            'montant_encaisse_annee' => $situationGlobale['montant_paye'],
            'reste_a_recouvrer'      => round($situationGlobale['montant_attendu'] - $situationGlobale['montant_paye'], 2),
            'total_encaisse_periode' => round($paiements->sum('montant'), 2),
            'par_mode_paiement'      => $this->ventilerParMode($paiements),
            'par_classe'             => $this->ventilerParClasse($paiements),
        ];
    }

    // Montant total attendu/payé de l'école pour une année scolaire, en
    // sommant la situation individuelle (FraisCalculService) de chaque élève.
    private function situationGlobale(AnneeAcademique $annee): array
    {
        $eleves = Eleve::where('ecole_id', $annee->ecole_id)
            ->whereHas('inscriptions', fn ($q) => $q->where('annee_academique_id', $annee->id))
            ->get();

        $attendu = 0.0;
        $paye = 0.0;

        foreach ($eleves as $eleve) {
            $situation = $this->fraisCalcul->situationEleve($eleve, $annee->id);
            $attendu += $situation['montant_attendu'];
            $paye += $situation['montant_paye'];
        }

        return ['montant_attendu' => round($attendu, 2), 'montant_paye' => round($paye, 2)];
    }

    private function ventilerParMode($paiements): array
    {
        return collect(self::MODES_PAIEMENT)
            ->map(function ($libelle, $mode) use ($paiements) {
                $sousEnsemble = $paiements->where('mode_paiement', $mode);

                return [
                    'mode'    => $mode,
                    'libelle' => $libelle,
                    'nombre'  => $sousEnsemble->count(),
                    'montant' => round($sousEnsemble->sum('montant'), 2),
                ];
            })
            ->values()
            ->all();
    }

    private function ventilerParClasse($paiements): array
    {
        return $paiements
            ->groupBy(function (Paiement $p) {
                $inscription = $p->eleve?->inscriptions
                    ->firstWhere('annee_academique_id', $p->fraisScolaire?->annee_scolaire_id);

                return $inscription?->classe?->nom ?? 'Non affecté';
            })
            ->map(fn ($groupe, $classeNom) => [
                'classe_nom' => $classeNom,
                'nombre'     => $groupe->count(),
                'montant'    => round($groupe->sum('montant'), 2),
            ])
            ->sortByDesc('montant')
            ->values()
            ->all();
    }

    private function formaterTransaction(Paiement $p): array
    {
        return [
            'id'            => $p->id,
            'numero_recu'   => $p->numero_recu,
            'eleve'         => trim(($p->eleve->nom ?? '') . ' ' . ($p->eleve->prenom ?? '')),
            'frais_nom'     => $p->fraisScolaire->nom ?? null,
            'mode_paiement' => $p->mode_paiement,
            'montant'       => (float) $p->montant,
            'date_paiement' => Carbon::parse($p->date_paiement)->format('d/m/Y'),
        ];
    }
}
