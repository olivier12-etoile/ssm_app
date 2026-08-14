<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ParametreNotification;
use Illuminate\Http\Request;

class ParametreNotificationController extends Controller
{
    // GET /notifications/parametres-declencheurs
    public function index(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;

        // Les déclencheurs automatiques sont tous orientés parents : on
        // filtre sur cible pour ne jamais lire une valeur enregistrée sous
        // la même clé côté "enseignants" par ParametreNotificationEcoleController.
        $valeurs = ParametreNotification::where('ecole_id', $ecoleId)
            ->where('cible', 'parents')
            ->pluck('valeur', 'cle');

        $declencheurs = collect(ParametreNotification::DECLENCHEURS)
            ->map(fn($libelle, $cle) => [
                'cle'     => $cle,
                'libelle' => $libelle,
                // Pas de ligne enregistrée = déclencheur actif par défaut.
                'actif'   => $valeurs->has($cle) ? (bool) $valeurs->get($cle) : true,
            ])
            ->values();

        return response()->json(['declencheurs' => $declencheurs]);
    }

    // PUT /notifications/parametres-declencheurs
    public function update(Request $request)
    {
        if (!in_array($request->user()->role, ['directeur', 'super_admin'], true)) {
            return response()->json([
                'message' => 'Seul le directeur peut configurer les déclencheurs automatiques.',
            ], 403);
        }

        $data = $request->validate([
            'cle'    => 'required|in:' . implode(',', array_keys(ParametreNotification::DECLENCHEURS)),
            'valeur' => 'required|boolean',
        ]);

        $parametre = ParametreNotification::updateOrCreate(
            ['ecole_id' => $request->user()->ecole_id, 'cible' => 'parents', 'cle' => $data['cle']],
            ['valeur' => $data['valeur']]
        );

        return response()->json(['parametre' => $parametre]);
    }
}
