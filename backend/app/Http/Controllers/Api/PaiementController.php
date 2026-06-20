<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Paiement;
use App\Models\Eleve;
use App\Models\Inscription;
use Illuminate\Http\Request;
use Barryvdh\DomPDF\Facade\Pdf;
use App\Models\NotificationAttente;
use App\Services\MessageTemplateService;

class PaiementController extends Controller
{
    // Liste des paiements de l'école
    public function index(Request $request)
    {
        $paiements = Paiement::whereHas('eleve', function ($q) use ($request) {
                $q->where('ecole_id', $request->user()->ecole_id);
            })
            ->with(['eleve', 'annee'])
            ->orderBy('date_paiement', 'desc')
            ->get();

        return response()->json($paiements);
    }

    // Paiements d'un élève
    public function parEleve(Request $request, $eleveId)
    {
        $paiements = Paiement::where('eleve_id', $eleveId)
            ->with('annee')
            ->orderBy('date_paiement', 'desc')
            ->get();

        $totalPaye = $paiements->sum('montant');

        return response()->json([
            'paiements'   => $paiements,
            'total_paye'  => $totalPaye,
        ]);
    }

    // Enregistrer un paiement
    public function enregistrer(Request $request)
{
    $request->validate([
        'eleve_id'            => 'required|integer',
        'annee_academique_id' => 'required|integer',
        'montant'             => 'required|numeric|min:1',
        'tranche'             => 'required|string|max:50',
        'date_paiement'       => 'required|date',
        'reference'           => 'nullable|string|max:50',
    ]);

    $paiement = Paiement::create([
        'eleve_id'            => $request->eleve_id,
        'annee_academique_id' => $request->annee_academique_id,
        'montant'             => $request->montant,
        'tranche'             => $request->tranche,
        'date_paiement'       => $request->date_paiement,
        'reference'           => $request->reference,
    ]);

    // ── Créer automatiquement la notification en attente ──
    $eleve = Eleve::with('ecole')->find($request->eleve_id);
    if ($eleve && $eleve->telephone_parent) {
        $message = MessageTemplateService::paiement(
            $eleve->nom . ' ' . $eleve->prenom,
            number_format($request->montant, 0, ',', ' '),
            $request->tranche,
            $eleve->ecole->nom ?? ''
        );

        NotificationAttente::create([
            'ecole_id'         => $request->user()->ecole_id,
            'eleve_id'         => $eleve->id,
            'type'             => 'paiement',
            'telephone_parent' => $eleve->telephone_parent,
            'message'          => $message,
            'statut'           => 'en_attente',
        ]);
    }

    return response()->json([
        'message'  => 'Paiement enregistré avec succès',
        'paiement' => $paiement,
    ], 201);
}

    // Liste de renvoi — élèves non à jour
    public function listeRenvoi(Request $request)
    {
        $request->validate([
            'classe_id'           => 'required|integer',
            'annee_academique_id' => 'required|integer',
            'montant_exige'       => 'required|numeric',
        ]);

        // Élèves de la classe
        $eleves = Eleve::where('ecole_id', $request->user()->ecole_id)
            ->whereHas('inscriptions', function ($q) use ($request) {
                $q->where('classe_id', $request->classe_id)
                  ->where('annee_academique_id', $request->annee_academique_id);
            })
            ->with(['paiements' => function ($q) use ($request) {
                $q->where('annee_academique_id', $request->annee_academique_id);
            }])
            ->get();

        $nonAJour = [];

        foreach ($eleves as $eleve) {
            $totalPaye = $eleve->paiements->sum('montant');
            $dette     = $request->montant_exige - $totalPaye;

            if ($dette > 0) {
                $nonAJour[] = [
                    'id'          => $eleve->id,
                    'nom'         => $eleve->nom,
                    'prenom'      => $eleve->prenom,
                    'matricule'   => $eleve->matricule,
                    'total_paye'  => $totalPaye,
                    'montant_du'  => $dette,
                ];
            }
        }

        return response()->json([
            'classe_id'     => $request->classe_id,
            'montant_exige' => $request->montant_exige,
            'non_a_jour'    => $nonAJour,
            'total'         => count($nonAJour),
        ]);
    }

    // Statistiques paiements
    public function statistiques(Request $request)
    {
        $anneeId = $request->query('annee_id');

        $totalEncaisse = Paiement::whereHas('eleve', function ($q) use ($request) {
                $q->where('ecole_id', $request->user()->ecole_id);
            })
            ->when($anneeId, fn($q) => $q->where('annee_academique_id', $anneeId))
            ->sum('montant');

        $nombrePaiements = Paiement::whereHas('eleve', function ($q) use ($request) {
                $q->where('ecole_id', $request->user()->ecole_id);
            })
            ->when($anneeId, fn($q) => $q->where('annee_academique_id', $anneeId))
            ->count();

        return response()->json([
            'total_encaisse'   => $totalEncaisse,
            'nombre_paiements' => $nombrePaiements,
        ]);
    }

    public function genererRecuPdf(Request $request, $paiementId)
{
    $paiement = Paiement::where('id', $paiementId)
        ->whereHas('eleve', function ($q) use ($request) {
            $q->where('ecole_id', $request->user()->ecole_id);
        })
        ->with(['eleve.ecole', 'annee'])
        ->firstOrFail();

    $data = [
        'numero_recu'    => 'REC-' . str_pad($paiement->id, 6, '0', STR_PAD_LEFT),
        'eleve'          => [
            'nom'       => $paiement->eleve->nom,
            'prenom'    => $paiement->eleve->prenom,
            'matricule' => $paiement->eleve->matricule,
        ],
        'annee'          => $paiement->annee->libelle,
        'tranche'        => $paiement->tranche,
        'montant'        => $paiement->montant,
        'date_paiement'  => \Carbon\Carbon::parse($paiement->date_paiement)->format('d/m/Y'),
        'reference'      => $paiement->reference,
        'ecole'          => [
            'nom'              => $paiement->eleve->ecole->nom,
            'code_ecole'       => $paiement->eleve->ecole->code_ecole,
            'couleur_primaire' => $paiement->eleve->ecole->couleur_primaire,
            'telephone'        => $paiement->eleve->ecole->telephone,
            'adresse'          => $paiement->eleve->ecole->adresse,
        ],
        'genere_le'      => now()->format('d/m/Y à H:i'),
    ];

    $pdf = Pdf::loadView('pdf.recu', $data);
    $nomFichier = 'recu_' . $data['numero_recu'] . '.pdf';

    return $pdf->download($nomFichier);
}
}