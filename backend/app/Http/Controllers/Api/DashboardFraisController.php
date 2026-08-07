<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\Eleve;
use App\Models\JournalOperationFrais;
use App\Models\Paiement;
use App\Services\FraisCalculService;
use Barryvdh\DomPDF\Facade\Pdf;
use Carbon\Carbon;
use Illuminate\Http\Request;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

class DashboardFraisController extends Controller
{
    private const MOIS_FR = [
        1 => 'Janvier', 2 => 'Février', 3 => 'Mars', 4 => 'Avril',
        5 => 'Mai', 6 => 'Juin', 7 => 'Juillet', 8 => 'Août',
        9 => 'Septembre', 10 => 'Octobre', 11 => 'Novembre', 12 => 'Décembre',
    ];

    public function __construct(private FraisCalculService $fraisCalcul)
    {
    }

    // ════════════════════════════════════════════════════════════
    // 1. Résumé du tableau de bord
    // ════════════════════════════════════════════════════════════
    public function resume(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        $annee = $this->anneeActive($ecoleId);

        if (!$annee) {
            return response()->json(['message' => 'Aucune année scolaire active.'], 404);
        }

        $eleves = $this->elevesAnnee($ecoleId, $annee->id);
        $situations = $this->situationsEleves($eleves, $annee->id);

        $montantAttendu   = $situations->sum(fn($s) => $s['situation']['montant_attendu']);
        $montantEncaisse  = $situations->sum(fn($s) => $s['situation']['montant_paye']);
        $montantRestant   = round($montantAttendu - $montantEncaisse, 2);

        $aJour           = $situations->filter(fn($s) => $s['situation']['reste_a_payer'] <= 0)->count();
        $partiel         = $situations->filter(fn($s) => $s['situation']['montant_paye'] > 0 && $s['situation']['reste_a_payer'] > 0)->count();
        $aucunPaiement   = $situations->filter(fn($s) => $s['situation']['montant_paye'] <= 0 && $s['situation']['montant_attendu'] > 0)->count();

        $tauxRecouvrement = $montantAttendu > 0 ? round($montantEncaisse / $montantAttendu * 100, 1) : 0;

        return response()->json([
            'annee_scolaire_id'           => $annee->id,
            'annee_libelle'               => $annee->libelle,
            'montant_attendu'             => round($montantAttendu, 2),
            'montant_encaisse'            => round($montantEncaisse, 2),
            'montant_restant'             => $montantRestant,
            'nombre_eleves_a_jour'        => $aJour,
            'nombre_eleves_partiel'       => $partiel,
            'nombre_eleves_aucun_paiement'=> $aucunPaiement,
            'taux_recouvrement'           => $tauxRecouvrement,
            'evolution_mensuelle'         => $this->recettesParMoisDetail($annee),
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 2. Élèves débiteurs
    // ════════════════════════════════════════════════════════════
    public function debiteurs(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        $annee = $this->anneeActive($ecoleId);

        if (!$annee) {
            return response()->json(['message' => 'Aucune année scolaire active.'], 404);
        }

        $eleves = $this->elevesAnnee($ecoleId, $annee->id, $request->integer('classe_id') ?: null);
        $situations = $this->situationsEleves($eleves, $annee->id);

        $debiteurs = $situations
            ->filter(fn($s) => $s['situation']['reste_a_payer'] > 0)
            ->map(fn($s) => $this->formaterDebiteur($s))
            ->values();

        if ($request->filled('jours_retard_min')) {
            $seuil = (int) $request->jours_retard_min;
            $debiteurs = $debiteurs->filter(fn($d) => $d['jours_de_retard'] >= $seuil)->values();
        }

        if ($request->filled('pourcentage_impaye_min')) {
            $seuil = (float) $request->pourcentage_impaye_min;
            $debiteurs = $debiteurs->filter(fn($d) => $d['pourcentage_impaye'] >= $seuil)->values();
        }

        if ($request->boolean('aucun_paiement')) {
            $debiteurs = $debiteurs->filter(fn($d) => $d['montant_paye'] <= 0)->values();
        }

        $debiteurs = match ($request->input('tri')) {
            'par_classe'     => $debiteurs->sortBy('classe_nom')->values(),
            'par_montant'    => $debiteurs->sortByDesc('montant_restant')->values(),
            'par_anciennete' => $debiteurs->sortByDesc('jours_de_retard')->values(),
            default          => $debiteurs,
        };

        return response()->json([
            'total'     => $debiteurs->count(),
            'debiteurs' => $debiteurs,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 3. Élèves à jour
    // ════════════════════════════════════════════════════════════
    public function elevesAJour(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        $annee = $this->anneeActive($ecoleId);

        if (!$annee) {
            return response()->json(['message' => 'Aucune année scolaire active.'], 404);
        }

        $eleves = $this->elevesAnnee($ecoleId, $annee->id, $request->integer('classe_id') ?: null);
        $situations = $this->situationsEleves($eleves, $annee->id);

        $aJour = $situations
            ->filter(fn($s) => $s['situation']['reste_a_payer'] <= 0)
            ->map(fn($s) => [
                'eleve_id'        => $s['eleve']->id,
                'nom'             => $s['eleve']->nom,
                'prenom'          => $s['eleve']->prenom,
                'matricule'       => $s['eleve']->matricule,
                'classe_nom'      => $s['classe']?->nom ?? 'Non affecté',
                'montant_attendu' => $s['situation']['montant_attendu'],
                'montant_paye'    => $s['situation']['montant_paye'],
            ])
            ->values();

        return response()->json([
            'total'   => $aJour->count(),
            'eleves'  => $aJour,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 4. Statistiques (graphiques)
    // ════════════════════════════════════════════════════════════
    public function statistiques(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        $annee = $this->anneeActive($ecoleId);

        if (!$annee) {
            return response()->json(['message' => 'Aucune année scolaire active.'], 404);
        }

        $eleves = $this->elevesAnnee($ecoleId, $annee->id);
        $situations = $this->situationsEleves($eleves, $annee->id);

        // ── Par classe ──
        $parClasse = $situations->groupBy(fn($s) => $s['classe']?->id ?? 0);
        $agregatClasses = $parClasse->map(function ($groupe) {
            $classe = $groupe->first()['classe'];
            $attendu = $groupe->sum(fn($s) => $s['situation']['montant_attendu']);
            $encaisse = $groupe->sum(fn($s) => $s['situation']['montant_paye']);
            return [
                'classe_id'   => $classe?->id,
                'classe_nom'  => $classe?->nom ?? 'Non affecté',
                'attendu'     => round($attendu, 2),
                'encaisse'    => round($encaisse, 2),
                'taux'        => $attendu > 0 ? round($encaisse / $attendu * 100, 1) : 0,
            ];
        })->values();

        $recettesParClasse = [
            'labels'  => $agregatClasses->pluck('classe_nom'),
            'valeurs' => $agregatClasses->pluck('encaisse'),
        ];

        // ── Par niveau ──
        $parNiveau = $situations->groupBy(fn($s) => $s['classe']?->niveau ?? 'Non affecté');
        $recettesParNiveau = [
            'labels'  => $parNiveau->keys()->values(),
            'valeurs' => $parNiveau->map(fn($g) => round($g->sum(fn($s) => $s['situation']['montant_paye']), 2))->values(),
        ];

        // ── Top classes ──
        $classesAvecTaux = $agregatClasses->filter(fn($c) => $c['attendu'] > 0);
        $topAJour = $classesAvecTaux->sortByDesc('taux')->take(5)->values();
        $topRetard = $classesAvecTaux->sortBy('taux')->take(5)->values();

        return response()->json([
            'recettes_par_mois'   => $this->recettesParMoisLabelsValeurs($annee),
            'recettes_par_classe' => $recettesParClasse,
            'recettes_par_niveau' => $recettesParNiveau,
            'top_classes_a_jour'  => $topAJour,
            'top_classes_retard'  => $topRetard,
        ]);
    }

    // ════════════════════════════════════════════════════════════
    // 5. Rapport téléchargeable (PDF ou Excel)
    // ════════════════════════════════════════════════════════════
    public function rapport(Request $request)
    {
        $request->validate([
            'periode'           => 'nullable|in:jour,semaine,mois,trimestre,annee',
            'date_debut'        => 'nullable|date',
            'date_fin'          => 'nullable|date',
            'format'            => 'nullable|in:pdf,excel',
            'annee_scolaire_id' => 'nullable|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;
        $ecole = $request->user()->ecole;
        $annee = $request->filled('annee_scolaire_id')
            ? AnneeAcademique::where('id', $request->annee_scolaire_id)->where('ecole_id', $ecoleId)->firstOrFail()
            : $this->anneeActive($ecoleId);

        if (!$annee) {
            return response()->json(['message' => 'Aucune année scolaire active.'], 404);
        }

        // Si on cible explicitement une année scolaire (potentiellement
        // passée) sans préciser de période, on couvre toute sa durée plutôt
        // que l'année civile en cours (par défaut de resoudrePeriode()).
        if ($request->filled('annee_scolaire_id') && !$request->filled('periode') && !$request->filled('date_debut')) {
            $debut = Carbon::parse($annee->date_debut)->startOfDay();
            $fin = Carbon::parse($annee->date_fin)->endOfDay();
            $periodeLibelle = 'Annee_scolaire_' . str_replace([' ', '/'], '_', $annee->libelle);
        } else {
            [$debut, $fin, $periodeLibelle] = $this->resoudrePeriode($request);
        }

        $eleves = $this->elevesAnnee($ecoleId, $annee->id);
        $situations = $this->situationsEleves($eleves, $annee->id);
        $montantAttendu  = round($situations->sum(fn($s) => $s['situation']['montant_attendu']), 2);
        $montantEncaisse = round($situations->sum(fn($s) => $s['situation']['montant_paye']), 2);

        $paiements = Paiement::with(['eleve', 'fraisScolaire'])
            ->where('statut', 'valide')
            ->whereHas('fraisScolaire', fn($q) => $q->where('annee_scolaire_id', $annee->id))
            ->whereBetween('date_paiement', [$debut->format('Y-m-d'), $fin->format('Y-m-d')])
            ->orderBy('date_paiement')
            ->get();

        $totalPeriode = round($paiements->sum('montant'), 2);

        $data = [
            'ecole' => [
                'nom'              => $ecole->nom,
                'code_ecole'       => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'periode_libelle' => $periodeLibelle,
            'date_debut'      => $debut->format('d/m/Y'),
            'date_fin'        => $fin->format('d/m/Y'),
            'recapitulatif'   => [
                'montant_attendu'  => $montantAttendu,
                'montant_encaisse' => $montantEncaisse,
                'montant_restant'  => round($montantAttendu - $montantEncaisse, 2),
            ],
            'total_periode' => $totalPeriode,
            'paiements'     => $paiements,
            'genere_le'     => now()->format('d/m/Y à H:i'),
        ];

        if ($request->input('format') === 'excel') {
            return $this->genererRapportExcel($data);
        }

        $pdf = Pdf::loadView('pdf.rapport_frais', $data);

        return $pdf->download('rapport_financier_' . $periodeLibelle . '.pdf');
    }

    private function genererRapportExcel(array $data)
    {
        $spreadsheet = new Spreadsheet();
        $feuille = $spreadsheet->getActiveSheet();
        $feuille->setTitle('Rapport financier');

        $feuille->fromArray(['Récapitulatif', $data['periode_libelle']], null, 'A1');
        $feuille->fromArray(['Montant attendu', $data['recapitulatif']['montant_attendu']], null, 'A2');
        $feuille->fromArray(['Montant encaissé', $data['recapitulatif']['montant_encaisse']], null, 'A3');
        $feuille->fromArray(['Reste à recouvrer', $data['recapitulatif']['montant_restant']], null, 'A4');
        $feuille->fromArray(['Encaissé sur la période', $data['total_periode']], null, 'A5');

        $feuille->fromArray(['N° Reçu', 'Date', 'Élève', 'Frais', 'Mode', 'Montant'], null, 'A7');
        $ligne = 8;
        foreach ($data['paiements'] as $p) {
            $feuille->fromArray([
                $p->numero_recu,
                $p->date_paiement->format('d/m/Y'),
                $p->eleve->nom . ' ' . $p->eleve->prenom,
                $p->fraisScolaire->nom,
                $p->mode_paiement,
                $p->montant,
            ], null, "A{$ligne}");
            $ligne++;
        }

        return $this->telechargerSpreadsheet($spreadsheet, 'rapport_financier_' . $data['periode_libelle'] . '.xlsx');
    }

    // ════════════════════════════════════════════════════════════
    // 6. Journal des opérations
    // ════════════════════════════════════════════════════════════
    public function journalOperations(Request $request)
    {
        $journal = JournalOperationFrais::with(['user:id,name', 'paiement:id,numero_recu,montant'])
            ->when($request->filled('user_id'), fn($q) => $q->where('user_id', $request->user_id))
            ->when($request->filled('action'), fn($q) => $q->where('action', $request->action))
            ->when($request->filled('date_debut'), fn($q) => $q->whereDate('created_at', '>=', $request->date_debut))
            ->when($request->filled('date_fin'), fn($q) => $q->whereDate('created_at', '<=', $request->date_fin))
            ->orderByDesc('created_at')
            ->paginate(30);

        return response()->json($journal);
    }

    // ════════════════════════════════════════════════════════════
    // Exports débiteurs
    // ════════════════════════════════════════════════════════════

    public function exportDebiteursExcel(Request $request)
    {
        $debiteurs = $this->recupererDebiteursGroupes($request);

        $spreadsheet = new Spreadsheet();
        $feuille = $spreadsheet->getActiveSheet();
        $feuille->setTitle('Débiteurs');
        $feuille->fromArray(['Nom', 'Classe', 'Matricule', 'Montant restant', 'Jours retard', 'Téléphone parent'], null, 'A1');

        $ligne = 2;
        foreach ($debiteurs['classes'] as $eleves) {
            foreach ($eleves as $e) {
                $feuille->fromArray([
                    $e['nom'] . ' ' . $e['prenom'],
                    $e['classe_nom'],
                    $e['matricule'],
                    $e['montant_restant'],
                    $e['jours_de_retard'],
                    $e['telephone_parent'] ?? '',
                ], null, "A{$ligne}");
                $ligne++;
            }
        }

        return $this->telechargerSpreadsheet($spreadsheet, 'debiteurs.xlsx');
    }

    public function exportDebiteursPdf(Request $request)
    {
        $ecole = $request->user()->ecole;
        $debiteurs = $this->recupererDebiteursGroupes($request);

        $pdf = Pdf::loadView('pdf.debiteurs_frais', [
            'ecole' => [
                'nom'              => $ecole->nom,
                'code_ecole'       => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
            ],
            'classes'   => $debiteurs['classes'],
            'total'     => $debiteurs['total'],
            'genere_le' => now()->format('d/m/Y à H:i'),
        ]);

        return $pdf->download('debiteurs.pdf');
    }

    private function recupererDebiteursGroupes(Request $request): array
    {
        $ecoleId = $request->user()->ecole_id;
        $annee = $this->anneeActive($ecoleId);

        if (!$annee) {
            return ['total' => 0, 'classes' => collect()];
        }

        $eleves = $this->elevesAnnee($ecoleId, $annee->id, $request->integer('classe_id') ?: null);
        $situations = $this->situationsEleves($eleves, $annee->id);

        $debiteurs = $situations
            ->filter(fn($s) => $s['situation']['reste_a_payer'] > 0)
            ->map(fn($s) => $this->formaterDebiteur($s))
            ->values();

        return [
            'total'   => $debiteurs->count(),
            'classes' => $debiteurs->groupBy('classe_nom'),
        ];
    }

    // ── Aides internes ────────────────────────────────────────────

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

    private function anneeActive(int $ecoleId): ?AnneeAcademique
    {
        return AnneeAcademique::where('ecole_id', $ecoleId)->where('statut', 'active')->first();
    }

    // Élèves inscrits pour l'année donnée (optionnellement filtrés par classe).
    private function elevesAnnee(int $ecoleId, int $anneeId, ?int $classeId = null)
    {
        return Eleve::where('ecole_id', $ecoleId)
            ->whereHas('inscriptions', function ($q) use ($anneeId, $classeId) {
                $q->where('annee_academique_id', $anneeId);
                if ($classeId) {
                    $q->where('classe_id', $classeId);
                }
            })
            ->with(['inscriptions' => fn($q) => $q->where('annee_academique_id', $anneeId)->with('classe')])
            ->orderBy('nom')
            ->get();
    }

    // Calcule, pour chaque élève, sa situation financière + sa classe actuelle.
    private function situationsEleves($eleves, int $anneeId)
    {
        return $eleves->map(function (Eleve $eleve) use ($anneeId) {
            $classe = $eleve->inscriptions->first()?->classe;
            return [
                'eleve'     => $eleve,
                'classe'    => $classe,
                'situation' => $this->fraisCalcul->situationEleve($eleve, $anneeId),
            ];
        });
    }

    private function formaterDebiteur(array $s): array
    {
        $eleve = $s['eleve'];
        $situation = $s['situation'];
        $classe = $s['classe'];

        $fraisEnRetard = collect($situation['frais'])
            ->filter(fn($f) => $f['reste_a_payer'] > 0 && Carbon::parse($f['date_limite'])->isPast());

        $joursDeRetard = 0;
        if ($fraisEnRetard->isNotEmpty()) {
            $dateLaPlusAncienne = $fraisEnRetard->min('date_limite');
            $joursDeRetard = (int) Carbon::parse($dateLaPlusAncienne)->diffInDays(now());
        }

        $pourcentageImpaye = $situation['montant_attendu'] > 0
            ? round($situation['reste_a_payer'] / $situation['montant_attendu'] * 100, 1)
            : 0;

        return [
            'eleve_id'            => $eleve->id,
            'nom'                 => $eleve->nom,
            'prenom'              => $eleve->prenom,
            'matricule'           => $eleve->matricule,
            'classe_id'           => $classe?->id,
            'classe_nom'          => $classe?->nom ?? 'Non affecté',
            'montant_attendu'     => $situation['montant_attendu'],
            'montant_paye'        => $situation['montant_paye'],
            'montant_restant'     => $situation['reste_a_payer'],
            'pourcentage_impaye'  => $pourcentageImpaye,
            'jours_de_retard'     => $joursDeRetard,
            'telephone_parent'    => $eleve->telephone_parent,
        ];
    }

    // Résout (début, fin, libellé) à partir des paramètres periode/date_debut/date_fin.
    private function resoudrePeriode(Request $request): array
    {
        if ($request->filled('date_debut') && $request->filled('date_fin')) {
            $debut = Carbon::parse($request->date_debut)->startOfDay();
            $fin   = Carbon::parse($request->date_fin)->endOfDay();
            return [$debut, $fin, $debut->format('d-m-Y') . '_au_' . $fin->format('d-m-Y')];
        }

        $maintenant = now();

        return match ($request->input('periode', 'mois')) {
            'jour'      => [$maintenant->copy()->startOfDay(), $maintenant->copy()->endOfDay(), 'Jour_' . $maintenant->format('d-m-Y')],
            'semaine'   => [$maintenant->copy()->startOfWeek(), $maintenant->copy()->endOfWeek(), 'Semaine_' . $maintenant->format('W-Y')],
            'trimestre' => [$maintenant->copy()->startOfQuarter(), $maintenant->copy()->endOfQuarter(), 'Trimestre_' . $maintenant->quarter . '-' . $maintenant->year],
            'annee'     => [$maintenant->copy()->startOfYear(), $maintenant->copy()->endOfYear(), 'Annee_' . $maintenant->year],
            default     => [$maintenant->copy()->startOfMonth(), $maintenant->copy()->endOfMonth(), self::MOIS_FR[$maintenant->month] . '_' . $maintenant->year],
        };
    }

    // 12 mois glissants depuis le début de l'année scolaire, avec libellés français.
    private function recettesParMoisDetail(AnneeAcademique $annee): array
    {
        $debut = Carbon::parse($annee->date_debut)->startOfMonth();
        $resultat = [];

        for ($i = 0; $i < 12; $i++) {
            $mois = $debut->copy()->addMonths($i);
            $montant = Paiement::where('statut', 'valide')
                ->whereHas('fraisScolaire', fn($q) => $q->where('annee_scolaire_id', $annee->id))
                ->whereYear('date_paiement', $mois->year)
                ->whereMonth('date_paiement', $mois->month)
                ->sum('montant');

            $resultat[] = [
                'mois'    => $mois->format('Y-m'),
                'libelle' => self::MOIS_FR[$mois->month] . ' ' . $mois->year,
                'montant' => round((float) $montant, 2),
            ];
        }

        return $resultat;
    }

    private function recettesParMoisLabelsValeurs(AnneeAcademique $annee): array
    {
        $detail = $this->recettesParMoisDetail($annee);

        return [
            'labels'  => array_column($detail, 'libelle'),
            'valeurs' => array_column($detail, 'montant'),
        ];
    }
}
