<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\NotificationAttente;
use Illuminate\Http\Request;

class NotificationAttenteController extends Controller
{
    // Liste des notifications en attente (avec filtre type optionnel)
    public function index(Request $request)
    {
        $query = NotificationAttente::where('ecole_id', $request->user()->ecole_id)
            ->where('statut', 'en_attente')
            ->with('eleve')
            ->orderBy('created_at', 'asc');

        if ($request->has('type') && $request->type !== 'tout') {
            $query->where('type', $request->type);
        }

        $notifications = $query->get();

        return response()->json([
            'notifications' => $notifications,
            'total'          => $notifications->count(),
            'par_type'       => [
                'absence'  => NotificationAttente::where('ecole_id', $request->user()->ecole_id)
                                ->where('statut', 'en_attente')->where('type', 'absence')->count(),
                'paiement' => NotificationAttente::where('ecole_id', $request->user()->ecole_id)
                                ->where('statut', 'en_attente')->where('type', 'paiement')->count(),
                'bulletin' => NotificationAttente::where('ecole_id', $request->user()->ecole_id)
                                ->where('statut', 'en_attente')->where('type', 'bulletin')->count(),
            ],
        ]);
    }

    // Marquer comme envoyée
    public function marquerEnvoyee(Request $request, $id)
    {
        $notif = NotificationAttente::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $notif->update([
            'statut'     => 'envoyee',
            'envoyee_le' => now(),
        ]);

        return response()->json(['message' => 'Marquée comme envoyée']);
    }

    // Supprimer une notification (annuler l'envoi)
    public function supprimer(Request $request, $id)
    {
        $notif = NotificationAttente::where('id', $id)
            ->where('ecole_id', $request->user()->ecole_id)
            ->firstOrFail();

        $notif->delete();

        return response()->json(['message' => 'Notification supprimée']);
    }
}