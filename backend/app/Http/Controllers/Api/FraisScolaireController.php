<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnneeAcademique;
use App\Models\Classe;
use App\Models\Ecole;
use App\Models\Eleve;
use App\Models\FraisScolaire;
use App\Models\Inscription;
use App\Models\Paiement;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class FraisScolaireController extends Controller
{
    // Liste des frais d'une classe pour une année
    public function index(Request $request)
    {
        $request->validate([
            'classe_id' => 'required|integer',
            'annee_id'  => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;

        Classe::where('id', $request->classe_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $frais = FraisScolaire::where('classe_id', $request->classe_id)
            ->where('annee_academique_id', $request->annee_id)
            ->where('ecole_id', $ecoleId)
            ->get();

        return response()->json($frais);
    }

    // Créer ou mettre à jour les frais d'une classe (directeur uniquement)
    public function enregistrer(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Action réservée au directeur',
            ], 403);
        }

        $request->validate([
            'classe_id'           => 'required|integer',
            'annee_academique_id' => 'required|integer',
            'type'                => 'required|in:inscription,scolarite',
            'montant_total'       => 'required|numeric|min:0',
            'montant_tranche_1'   => 'nullable|numeric|min:0',
            'montant_tranche_2'   => 'nullable|numeric|min:0',
            'montant_tranche_3'   => 'nullable|numeric|min:0',
        ]);

        $ecoleId = $request->user()->ecole_id;

        Classe::where('id', $request->classe_id)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $frais = FraisScolaire::updateOrCreate(
            [
                'classe_id'           => $request->classe_id,
                'annee_academique_id' => $request->annee_academique_id,
                'type'                => $request->type,
            ],
            [
                'ecole_id'          => $ecoleId,
                'montant_total'     => $request->montant_total,
                'montant_tranche_1' => $request->montant_tranche_1,
                'montant_tranche_2' => $request->montant_tranche_2,
                'montant_tranche_3' => $request->montant_tranche_3,
            ]
        );

        return response()->json([
            'message' => 'Frais scolaires enregistrés avec succès',
            'frais'   => $frais,
        ], 201);
    }

    // Situation financière d'un élève
    public function situationEleve(Request $request, $eleveId)
    {
        $request->validate([
            'annee_id' => 'required|integer',
        ]);

        $ecoleId = $request->user()->ecole_id;
        $anneeId = $request->annee_id;

        $eleve = Eleve::where('id', $eleveId)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $inscription = Inscription::where('eleve_id', $eleve->id)
            ->where('annee_academique_id', $anneeId)
            ->first();

        $montantTotalDu = $inscription
            ? FraisScolaire::where('classe_id', $inscription->classe_id)
                ->where('annee_academique_id', $anneeId)
                ->sum('montant_total')
            : 0;

        $paiements = Paiement::where('eleve_id', $eleve->id)
            ->where('annee_academique_id', $anneeId)
            ->orderBy('date_paiement', 'desc')
            ->get();

        $montantPaye    = $paiements->sum('montant');
        $montantRestant = $montantTotalDu - $montantPaye;

        return response()->json([
            'eleve_id'         => $eleve->id,
            'nom'              => $eleve->nom,
            'prenom'           => $eleve->prenom,
            'matricule'        => $eleve->matricule,
            'montant_total_du' => $montantTotalDu,
            'montant_paye'     => $montantPaye,
            'montant_restant'  => $montantRestant,
            'statut'           => $this->statutPaiement($montantTotalDu, $montantPaye, $montantRestant),
            'historique'       => $paiements,
        ]);
    }

    // Situation financière de tous les élèves d'une classe
    public function situationClasse(Request $request)
    {
        $request->validate([
            'classe_id' => 'required|integer',
            'annee_id'  => 'required|integer',
        ]);

        $ecoleId  = $request->user()->ecole_id;
        $classeId = $request->classe_id;
        $anneeId  = $request->annee_id;

        $classe = Classe::where('id', $classeId)
            ->where('ecole_id', $ecoleId)
            ->firstOrFail();

        $montantParEleve = FraisScolaire::where('classe_id', $classeId)
            ->where('annee_academique_id', $anneeId)
            ->sum('montant_total');

        $eleves = Eleve::where('ecole_id', $ecoleId)
            ->whereHas('inscriptions', function ($q) use ($classeId, $anneeId) {
                $q->where('classe_id', $classeId)
                  ->where('annee_academique_id', $anneeId);
            })
            ->orderBy('nom')
            ->get();

        $paiementsParEleve = Paiement::whereIn('eleve_id', $eleves->pluck('id'))
            ->where('annee_academique_id', $anneeId)
            ->orderBy('date_paiement', 'desc')
            ->get()
            ->groupBy('eleve_id');

        $enRegle = 0;
        $partiel = 0;
        $nonPaye = 0;
        $totalEncaisse = 0;

        $situations = $eleves->map(function ($eleve) use (
            $montantParEleve,
            $paiementsParEleve,
            &$enRegle,
            &$partiel,
            &$nonPaye,
            &$totalEncaisse
        ) {
            $paiementsEleve = $paiementsParEleve->get($eleve->id, collect());
            $montantPaye    = $paiementsEleve->sum('montant');
            $montantRestant = $montantParEleve - $montantPaye;
            $statut         = $this->statutPaiement($montantParEleve, $montantPaye, $montantRestant);

            match ($statut) {
                'en_regle' => $enRegle++,
                'partiel'  => $partiel++,
                default    => $nonPaye++,
            };

            $totalEncaisse += $montantPaye;

            return [
                'eleve_id'         => $eleve->id,
                'nom'              => $eleve->nom,
                'prenom'           => $eleve->prenom,
                'montant_du'       => $montantParEleve,
                'montant_paye'     => $montantPaye,
                'montant_restant'  => $montantRestant,
                'statut'           => $statut,
                'dernier_paiement' => $paiementsEleve->first()?->date_paiement,
            ];
        });

        $totalAttendu = $montantParEleve * $eleves->count();

        return response()->json([
            'classe_id'    => $classe->id,
            'classe_nom'   => $classe->nom,
            'eleves'       => $situations,
            'statistiques' => [
                'total_eleves'   => $eleves->count(),
                'en_regle'       => $enRegle,
                'partiel'        => $partiel,
                'non_paye'       => $nonPaye,
                'total_attendu'  => $totalAttendu,
                'total_encaisse' => $totalEncaisse,
                'total_restant'  => $totalAttendu - $totalEncaisse,
            ],
        ]);
    }

    // Rapport financier complet de l'école
    public function rapportFinancier(Request $request)
    {
        $request->validate([
            'annee_id' => 'required|integer',
            'mois'     => 'nullable|integer|min:1|max:12',
        ]);

        $rapport = $this->calculerRapportFinancier(
            $request->user()->ecole_id,
            $request->annee_id,
            $request->mois
        );

        return response()->json($rapport);
    }

    // Rapport financier au format PDF
    public function genererRapportPdf(Request $request)
    {
        $request->validate([
            'annee_id' => 'required|integer',
            'mois'     => 'nullable|integer|min:1|max:12',
        ]);

        $ecole = Ecole::findOrFail($request->user()->ecole_id);
        $annee = AnneeAcademique::findOrFail($request->annee_id);

        $rapport = $this->calculerRapportFinancier(
            $ecole->id,
            $request->annee_id,
            $request->mois
        );

        $data = array_merge($rapport, [
            'ecole' => [
                'nom'              => $ecole->nom,
                'code_ecole'       => $ecole->code_ecole,
                'couleur_primaire' => $ecole->couleur_primaire,
                'telephone'        => $ecole->telephone,
                'adresse'          => $ecole->adresse,
            ],
            'annee_libelle' => $annee->libelle,
            'genere_le'     => now()->format('d/m/Y à H:i'),
        ]);

        $pdf = Pdf::loadView('pdf.rapport_financier', $data);
        $nomFichier = 'rapport_financier_' . $annee->libelle . ($request->mois ? '_' . $request->mois : '') . '.pdf';

        return $pdf->download($nomFichier);
    }

    // Calcule le rapport financier complet de l'école (utilisé par le JSON et le PDF)
    private function calculerRapportFinancier(int $ecoleId, int $anneeId, ?int $mois): array
    {
        $classes = Classe::where('ecole_id', $ecoleId)->orderBy('nom')->get();

        $parClasse          = [];
        $montantParClasse   = [];
        $nomParClasse       = [];
        $totalAttenduEcole  = 0;
        $totalEncaisseEcole = 0;

        foreach ($classes as $classe) {
            $montantParEleve = FraisScolaire::where('classe_id', $classe->id)
                ->where('annee_academique_id', $anneeId)
                ->sum('montant_total');

            $eleveIds = Eleve::where('ecole_id', $ecoleId)
                ->whereHas('inscriptions', function ($q) use ($classe, $anneeId) {
                    $q->where('classe_id', $classe->id)
                      ->where('annee_academique_id', $anneeId);
                })
                ->pluck('id');

            $totalAttendu = $montantParEleve * $eleveIds->count();

            $totalEncaisse = Paiement::whereIn('eleve_id', $eleveIds)
                ->where('annee_academique_id', $anneeId)
                ->when($mois, fn($q) => $q->whereMonth('date_paiement', $mois))
                ->sum('montant');

            $montantParClasse[$classe->id] = $montantParEleve;
            $nomParClasse[$classe->id]      = $classe->nom;
            $totalAttenduEcole  += $totalAttendu;
            $totalEncaisseEcole += $totalEncaisse;

            $parClasse[] = [
                'classe_id'         => $classe->id,
                'classe_nom'        => $classe->nom,
                'nombre_eleves'     => $eleveIds->count(),
                'montant_par_eleve' => $montantParEleve,
                'total_attendu'     => $totalAttendu,
                'total_encaisse'    => $totalEncaisse,
                'total_restant'     => $totalAttendu - $totalEncaisse,
            ];
        }

        // Débiteurs de l'école, sur l'année entière (indépendant du filtre mois)
        $eleves = Eleve::where('ecole_id', $ecoleId)
            ->whereHas('inscriptions', fn($q) => $q->where('annee_academique_id', $anneeId))
            ->with(['inscriptions' => fn($q) => $q->where('annee_academique_id', $anneeId)])
            ->get();

        $paiementsParEleve = Paiement::whereIn('eleve_id', $eleves->pluck('id'))
            ->where('annee_academique_id', $anneeId)
            ->select('eleve_id', DB::raw('SUM(montant) as total'))
            ->groupBy('eleve_id')
            ->pluck('total', 'eleve_id');

        $debiteurs = [];
        foreach ($eleves as $eleve) {
            $inscription = $eleve->inscriptions->first();
            if (!$inscription) {
                continue;
            }

            $montantDu      = $montantParClasse[$inscription->classe_id] ?? 0;
            $montantPaye    = $paiementsParEleve[$eleve->id] ?? 0;
            $montantRestant = $montantDu - $montantPaye;

            if ($montantRestant > 0) {
                $debiteurs[] = [
                    'eleve_id'        => $eleve->id,
                    'nom'             => $eleve->nom,
                    'prenom'          => $eleve->prenom,
                    'classe_id'       => $inscription->classe_id,
                    'classe_nom'      => $nomParClasse[$inscription->classe_id] ?? null,
                    'montant_du'      => $montantDu,
                    'montant_paye'    => $montantPaye,
                    'montant_restant' => $montantRestant,
                ];
            }
        }

        usort($debiteurs, fn($a, $b) => $b['montant_restant'] <=> $a['montant_restant']);

        return [
            'annee_id'     => $anneeId,
            'mois'         => $mois,
            'par_classe'   => $parClasse,
            'debiteurs'    => $debiteurs,
            'total_global' => [
                'total_attendu'  => $totalAttenduEcole,
                'total_encaisse' => $totalEncaisseEcole,
                'total_restant'  => $totalAttenduEcole - $totalEncaisseEcole,
            ],
        ];
    }

    private function statutPaiement(float $montantDu, float $montantPaye, float $montantRestant): string
    {
        if ($montantDu <= 0 || $montantRestant <= 0) {
            return 'en_regle';
        }
        if ($montantPaye <= 0) {
            return 'non_paye';
        }
        return 'partiel';
    }
}
