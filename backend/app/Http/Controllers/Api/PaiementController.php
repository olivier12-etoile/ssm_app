<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Eleve;
use App\Models\FraisScolaire;
use App\Models\JournalOperationFrais;
use App\Models\Paiement;
use App\Models\NotificationAttente;
use App\Services\CaisseService;
use App\Services\FraisCalculService;
use App\Services\MessageTemplateService;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;

class PaiementController extends Controller
{
    public function __construct(
        private FraisCalculService $fraisCalcul,
        private CaisseService $caisseService
    ) {
    }

    // GET /paiements
    public function index(Request $request)
    {
        $paiements = Paiement::with(['eleve', 'fraisScolaire', 'echeance', 'creePar'])
            ->when($request->filled('eleve_id'), fn($q) => $q->where('eleve_id', $request->eleve_id))
            ->when($request->filled('frais_scolaire_id'), fn($q) => $q->where('frais_scolaire_id', $request->frais_scolaire_id))
            ->when($request->filled('mode_paiement'), fn($q) => $q->where('mode_paiement', $request->mode_paiement))
            ->when($request->filled('statut'), fn($q) => $q->where('statut', $request->statut))
            ->when($request->filled('date_debut'), fn($q) => $q->whereDate('date_paiement', '>=', $request->date_debut))
            ->when($request->filled('date_fin'), fn($q) => $q->whereDate('date_paiement', '<=', $request->date_fin))
            ->orderByDesc('date_paiement')
            ->orderByDesc('id')
            ->get();

        return response()->json($paiements);
    }

    // POST /paiements
    public function store(Request $request)
    {
        $data = $request->validate([
            'eleve_id'          => 'required|integer',
            'frais_scolaire_id' => 'required|integer',
            'echeance_id'       => 'nullable|integer',
            'montant'           => 'required|numeric|min:1',
            'mode_paiement'     => 'required|in:especes,moov_money,wave,virement,cheque',
            'reference'         => 'nullable|string|max:255',
            'date_paiement'     => 'required|date',
            'observation'       => 'nullable|string',
        ]);

        $ecoleId = $request->user()->ecole_id;

        $eleve = Eleve::where('id', $data['eleve_id'])->where('ecole_id', $ecoleId)->firstOrFail();
        $frais = FraisScolaire::findOrFail($data['frais_scolaire_id']);

        $resteAPayer = $this->fraisCalcul->resteAPayer($eleve, $frais);

        if ($data['montant'] > $resteAPayer + 0.01) {
            return response()->json([
                'message'        => "Le montant dépasse le reste à payer ({$resteAPayer} FCFA).",
                'reste_a_payer'  => $resteAPayer,
            ], 422);
        }

        // Un paiement en espèces se rattache à la session de caisse ouverte
        // au moment du paiement, si elle existe — sans jamais bloquer
        // l'enregistrement du paiement quand aucune session n'est ouverte.
        $sessionCaisseId = null;
        if ($data['mode_paiement'] === 'especes') {
            $sessionCaisseId = $this->caisseService->sessionActivePourEcole($ecoleId)?->id;
        }

        $paiement = Paiement::create([
            'eleve_id'          => $eleve->id,
            'frais_scolaire_id' => $frais->id,
            'echeance_id'       => $data['echeance_id'] ?? null,
            'montant'           => $data['montant'],
            'mode_paiement'     => $data['mode_paiement'],
            'session_caisse_id' => $sessionCaisseId,
            'reference'         => $data['reference'] ?? null,
            'date_paiement'     => $data['date_paiement'],
            'observation'       => $data['observation'] ?? null,
            'statut'            => 'valide',
            'created_by'        => $request->user()->id,
        ]);

        JournalOperationFrais::create([
            'user_id'     => $request->user()->id,
            'action'      => 'paiement_enregistre',
            'description' => "Paiement de {$paiement->montant} FCFA pour {$eleve->nom} {$eleve->prenom} — {$frais->nom} (reçu {$paiement->numero_recu})",
            'paiement_id' => $paiement->id,
        ]);

        if ($eleve->telephone_parent) {
            NotificationAttente::create([
                'ecole_id'         => $ecoleId,
                'eleve_id'         => $eleve->id,
                'type'             => 'paiement',
                'telephone_parent' => $eleve->telephone_parent,
                'message'          => MessageTemplateService::paiement(
                    $eleve->nom . ' ' . $eleve->prenom,
                    number_format($paiement->montant, 0, ',', ' '),
                    $frais->nom,
                    $request->user()->ecole->nom ?? ''
                ),
                'statut' => 'en_attente',
            ]);
        }

        return response()->json([
            'message'  => 'Paiement enregistré avec succès',
            'paiement' => $paiement->load(['eleve', 'fraisScolaire', 'echeance']),
        ], 201);
    }

    // POST /paiements/{id}/annuler
    public function annuler(Request $request, $id)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut annuler un paiement.',
            ], 403);
        }

        $request->validate([
            'motif_annulation' => 'required|string|max:500',
        ]);

        $paiement = Paiement::findOrFail($id);

        if ($paiement->statut === 'annule') {
            return response()->json(['message' => 'Ce paiement est déjà annulé.'], 409);
        }

        $paiement->update([
            'statut'           => 'annule',
            'motif_annulation' => $request->motif_annulation,
            'annule_par'       => $request->user()->id,
        ]);

        JournalOperationFrais::create([
            'user_id'     => $request->user()->id,
            'action'      => 'paiement_annule',
            'description' => "Paiement {$paiement->numero_recu} annulé — Motif : {$request->motif_annulation}",
            'paiement_id' => $paiement->id,
        ]);

        return response()->json([
            'message'  => 'Paiement annulé avec succès',
            'paiement' => $paiement->fresh(),
        ]);
    }

    // GET /paiements/{id}/recu
    public function recu(Request $request, $id)
    {
        $paiement = Paiement::with(['eleve.ecole', 'fraisScolaire', 'echeance'])->findOrFail($id);

        $data = [
            'numero_recu'      => $paiement->numero_recu,
            'eleve'            => [
                'nom'       => $paiement->eleve->nom,
                'prenom'    => $paiement->eleve->prenom,
                'matricule' => $paiement->eleve->matricule,
            ],
            'frais_nom'        => $paiement->fraisScolaire->nom,
            'echeance_libelle' => $paiement->echeance?->libelle,
            'mode_paiement'    => match ($paiement->mode_paiement) {
                'especes'    => 'Espèces',
                'moov_money' => 'Moov Money',
                'wave'       => 'Wave',
                'virement'   => 'Virement',
                'cheque'     => 'Chèque',
                default      => $paiement->mode_paiement,
            },
            'montant'          => $paiement->montant,
            'date_paiement'    => $paiement->date_paiement->format('d/m/Y'),
            'reference'        => $paiement->reference,
            'statut'           => $paiement->statut,
            'ecole'            => [
                'nom'              => $paiement->eleve->ecole->nom,
                'code_ecole'       => $paiement->eleve->ecole->code_ecole,
                'couleur_primaire' => $paiement->eleve->ecole->couleur_primaire,
                'telephone'        => $paiement->eleve->ecole->telephone,
                'adresse'          => $paiement->eleve->ecole->adresse,
            ],
            'genere_le'        => now()->format('d/m/Y à H:i'),
        ];

        $pdf = Pdf::loadView('pdf.recu', $data);

        return $pdf->download('recu_' . $paiement->numero_recu . '.pdf');
    }
}
