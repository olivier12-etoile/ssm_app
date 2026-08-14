<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ParametreNotification;
use Illuminate\Http\Request;

/**
 * Liste des TYPES de notifications que l'école accepte de recevoir, par
 * destinataire (parents/enseignants) — ex. "Bulletin disponible",
 * "Paiement en retard", "Notes validées". Réutilise la table
 * parametres_notifications (ecole_id + cible + cle + valeur), scindée en
 * deux jeux de clés distincts : ParametreNotification::TYPES_NOTIFICATIONS
 * (géré ici) et ParametreNotification::DECLENCHEURS (les automatisations
 * techniques du module Notifications, gérées par
 * ParametreNotificationController — voir son commentaire de classe).
 *
 * À lire, à terme, par NotificationController/DeclencheurNotificationService
 * avant d'envoyer une notification d'un type donné : si le type est
 * désactivé pour sa cible, ne pas créer/envoyer la notification.
 */
class ParametreNotificationEcoleController extends Controller
{
    // GET /parametres/notifications-ecole?cible=parents|enseignants (optionnel)
    public function show(Request $request)
    {
        $data = $request->validate([
            'cible' => 'nullable|in:parents,enseignants',
        ]);

        $ecoleId = $request->user()->ecole_id;
        $cibles  = isset($data['cible']) ? [$data['cible']] : array_keys(ParametreNotification::TYPES_NOTIFICATIONS);

        $valeursParCible = ParametreNotification::where('ecole_id', $ecoleId)
            ->whereIn('cible', $cibles)
            ->get(['cible', 'cle', 'valeur'])
            ->groupBy('cible')
            ->map(fn($lignes) => $lignes->pluck('valeur', 'cle'));

        $resultat = [];
        foreach ($cibles as $cible) {
            $valeurs = $valeursParCible->get($cible, collect());

            // Absence de ligne pour (ecole, cible, cle) = type actif par défaut.
            $resultat[$cible] = collect(ParametreNotification::TYPES_NOTIFICATIONS[$cible])
                ->map(fn($libelle, $cle) => [
                    'cle'     => $cle,
                    'libelle' => $libelle,
                    'actif'   => $valeurs->has($cle) ? (bool) $valeurs->get($cle) : true,
                ])
                ->values();
        }

        return response()->json(['types_notifications' => $resultat]);
    }

    // PUT /parametres/notifications-ecole (directeur uniquement)
    public function update(Request $request)
    {
        if ($request->user()->role !== 'directeur') {
            return response()->json([
                'message' => 'Seul le directeur peut configurer les types de notifications.',
            ], 403);
        }

        $data = $request->validate([
            'cible'          => 'required|in:parents,enseignants',
            'type_evenement' => 'required|string',
            'actif'          => 'required|boolean',
        ]);

        if (!array_key_exists($data['type_evenement'], ParametreNotification::TYPES_NOTIFICATIONS[$data['cible']])) {
            return response()->json([
                'message' => "Type d'événement invalide pour la cible \"{$data['cible']}\".",
            ], 422);
        }

        $parametre = ParametreNotification::updateOrCreate(
            [
                'ecole_id' => $request->user()->ecole_id,
                'cible'    => $data['cible'],
                'cle'      => $data['type_evenement'],
            ],
            ['valeur' => $data['actif']]
        );

        return response()->json([
            'message'   => 'Type de notification mis à jour avec succès',
            'parametre' => $parametre,
        ]);
    }
}
