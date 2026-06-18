<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Paiement;
use App\Models\Eleve;
use App\Models\Inscription;
use Illuminate\Http\Request;

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
}