<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\NotificationDestinataire;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * Statistiques d'envoi du module Notifications, calculées à partir de
 * notifications/notification_destinataires (pas de table dédiée). Toutes
 * les routes acceptent date_debut/date_fin (défaut : 30 derniers jours).
 */
class StatistiqueNotificationController extends Controller
{
    // GET /notifications/statistiques
    public function resume(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        [$debut, $fin] = $this->periode($request);

        $notifications = Notification::where('ecole_id', $ecoleId)
            ->whereBetween('created_at', [$debut, $fin])
            ->get(['id', 'created_at']);

        $destinataires = NotificationDestinataire::whereIn('notification_id', $notifications->pluck('id'))
            ->get(['statut', 'notification_id']);

        $totalEnvoyees  = $destinataires->where('statut', 'envoye')->count();
        $totalDelivrees = $destinataires->where('statut', 'delivre')->count();
        $totalEchouees  = $destinataires->where('statut', 'echec')->count();
        $totalTraitees  = $totalEnvoyees + $totalDelivrees + $totalEchouees;

        $tauxReussite = $totalTraitees > 0
            ? round((($totalEnvoyees + $totalDelivrees) / $totalTraitees) * 100, 1)
            : 0.0;

        return response()->json([
            'total_envoyees'  => $totalEnvoyees,
            'total_delivrees' => $totalDelivrees,
            'total_echouees'  => $totalEchouees,
            'taux_reussite'   => $tauxReussite,
            'par_periode'     => $this->evolutionParJour($notifications, $destinataires, $debut, $fin),
        ]);
    }

    // GET /notifications/statistiques/par-canal
    public function parCanal(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        [$debut, $fin] = $this->periode($request);

        $resultat = Notification::where('ecole_id', $ecoleId)
            ->whereBetween('created_at', [$debut, $fin])
            ->selectRaw('canal, count(*) as total')
            ->groupBy('canal')
            ->pluck('total', 'canal');

        return response()->json(['par_canal' => $resultat]);
    }

    // GET /notifications/statistiques/par-categorie
    public function parCategorie(Request $request)
    {
        $ecoleId = $request->user()->ecole_id;
        [$debut, $fin] = $this->periode($request);

        $resultat = Notification::where('notifications.ecole_id', $ecoleId)
            ->whereBetween('notifications.created_at', [$debut, $fin])
            ->join('modeles_messages', 'modeles_messages.id', '=', 'notifications.modele_message_id')
            ->selectRaw('modeles_messages.categorie as categorie, count(*) as total')
            ->groupBy('modeles_messages.categorie')
            ->pluck('total', 'categorie');

        return response()->json(['par_categorie' => $resultat]);
    }

    private function periode(Request $request): array
    {
        $debut = $request->filled('date_debut')
            ? Carbon::parse($request->date_debut)->startOfDay()
            : now()->subDays(30)->startOfDay();

        $fin = $request->filled('date_fin')
            ? Carbon::parse($request->date_fin)->endOfDay()
            : now()->endOfDay();

        return [$debut, $fin];
    }

    // Évolution jour par jour sur la plage demandée (jours sans activité à 0,
    // pour que le graphique en ligne affiche une plage continue).
    private function evolutionParJour($notifications, $destinataires, Carbon $debut, Carbon $fin): array
    {
        $destinatairesParNotification = $destinataires->groupBy('notification_id');

        $jours = [];
        $curseur = $debut->copy()->startOfDay();
        while ($curseur->lte($fin)) {
            $jours[$curseur->toDateString()] = ['envoyees' => 0, 'delivrees' => 0, 'echouees' => 0];
            $curseur->addDay();
        }

        foreach ($notifications as $notification) {
            $jour = $notification->created_at->toDateString();
            if (!array_key_exists($jour, $jours)) {
                continue;
            }

            $siens = $destinatairesParNotification->get($notification->id, collect());
            $jours[$jour]['envoyees']  += $siens->where('statut', 'envoye')->count();
            $jours[$jour]['delivrees'] += $siens->where('statut', 'delivre')->count();
            $jours[$jour]['echouees']  += $siens->where('statut', 'echec')->count();
        }

        return collect($jours)
            ->map(fn($valeurs, $jour) => [
                'periode'   => $jour,
                'envoyees'  => $valeurs['envoyees'],
                'delivrees' => $valeurs['delivrees'],
                'echouees'  => $valeurs['echouees'],
            ])
            ->values()
            ->all();
    }
}
