<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppreciationBulletin;
use Illuminate\Http\Request;

class AppreciationController extends Controller
{
    // Récupérer l'appréciation d'un élève pour une période
    public function index(Request $request)
    {
        $request->validate([
            'eleve_id'   => 'required|integer',
            'periode_id' => 'required|integer',
        ]);

        $appreciation = AppreciationBulletin::where('eleve_id', $request->eleve_id)
            ->where('periode_id', $request->periode_id)
            ->first();

        return response()->json($appreciation ?? [
            'eleve_id'                 => $request->eleve_id,
            'periode_id'                => $request->periode_id,
            'appreciation_enseignant'   => null,
            'appreciation_directeur'    => null,
            'observation'               => null,
        ]);
    }

    // Créer ou mettre à jour l'appréciation (selon le rôle)
    public function enregistrer(Request $request)
    {
        $request->validate([
            'eleve_id'                => 'required|integer',
            'periode_id'              => 'required|integer',
            'appreciation_enseignant' => 'nullable|string|max:500',
            'appreciation_directeur'  => 'nullable|string|max:500',
            'observation'             => 'nullable|string|max:100',
        ]);

        $role = $request->user()->role;
        $donnees = ['eleve_id' => $request->eleve_id, 'periode_id' => $request->periode_id];

        // Un enseignant ne peut modifier QUE son champ
        if ($role === 'enseignant') {
            $donnees['appreciation_enseignant'] = $request->appreciation_enseignant;
        }
        // Directeur et Censeur peuvent tout modifier
        elseif (in_array($role, ['directeur', 'censeur'])) {
            if ($request->has('appreciation_enseignant')) {
                $donnees['appreciation_enseignant'] = $request->appreciation_enseignant;
            }
            if ($request->has('appreciation_directeur')) {
                $donnees['appreciation_directeur'] = $request->appreciation_directeur;
            }
            if ($request->has('observation')) {
                $donnees['observation'] = $request->observation;
            }
        } else {
            return response()->json(['message' => 'Action non autorisée pour ce rôle'], 403);
        }

        $appreciation = AppreciationBulletin::updateOrCreate(
            [
                'eleve_id'   => $request->eleve_id,
                'periode_id' => $request->periode_id,
            ],
            $donnees
        );

        return response()->json([
            'message'      => 'Appréciation enregistrée',
            'appreciation' => $appreciation,
        ]);
    }

    // Suggestion automatique d'observation selon la moyenne
    public function suggererObservation(Request $request)
    {
        $moyenne = (float) $request->query('moyenne', 0);

        $observation = match (true) {
            $moyenne >= 16 => 'Félicitations',
            $moyenne >= 14 => 'Encouragements',
            $moyenne >= 12 => 'Tableau d\'honneur',
            $moyenne >= 10 => 'Travail satisfaisant',
            $moyenne >= 8  => 'Doit fournir davantage d\'efforts',
            default        => 'Avertissement - Travail insuffisant',
        };

        return response()->json(['observation_suggeree' => $observation]);
    }
}