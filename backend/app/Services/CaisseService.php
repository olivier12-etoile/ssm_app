<?php

namespace App\Services;

use App\Models\Caisse;
use App\Models\Paiement;
use App\Models\SessionCaisse;

/**
 * Gère le cycle de vie des sessions de caisse (ouverture/fermeture) et le
 * rapprochement espèces qui en découle.
 *
 * Règle importante : une seule session peut être "ouverte" à la fois pour
 * une même caisse.
 */
class CaisseService
{
    // Ouvre une nouvelle session pour la caisse donnée. Échoue si une
    // session est déjà ouverte pour cette caisse.
    public function ouvrir(int $caisseId, float $montantInitial, int $ouvertParId): SessionCaisse
    {
        $caisse = Caisse::findOrFail($caisseId);

        if ($this->sessionActive($caisse->id)) {
            throw new \InvalidArgumentException('Une session est déjà ouverte pour cette caisse.');
        }

        return SessionCaisse::create([
            'caisse_id'       => $caisse->id,
            'ouvert_par'      => $ouvertParId,
            'montant_initial' => $montantInitial,
            'date_ouverture'  => now(),
            'statut'          => 'ouverte',
        ]);
    }

    // Ferme la session ouverte donnée : calcule le montant théorique à
    // partir des paiements espèces rattachés, compare au montant réel
    // compté par l'utilisateur, et enregistre l'écart.
    public function fermer(int $sessionId, float $montantReel, ?string $observation, int $fermeParId): SessionCaisse
    {
        $session = SessionCaisse::where('statut', 'ouverte')->find($sessionId);

        if (!$session) {
            throw new \InvalidArgumentException('Aucune session ouverte trouvée pour cet identifiant.');
        }

        $totalEspeces = Paiement::where('session_caisse_id', $session->id)
            ->where('statut', 'valide')
            ->sum('montant');

        $montantTheorique = round((float) $session->montant_initial + (float) $totalEspeces, 2);
        $ecart = round($montantReel - $montantTheorique, 2);

        $session->update([
            'ferme_par'             => $fermeParId,
            'date_fermeture'        => now(),
            'montant_theorique'     => $montantTheorique,
            'montant_reel'          => $montantReel,
            'ecart'                 => $ecart,
            'observation_fermeture' => $observation,
            'statut'                => 'fermee',
        ]);

        return $session->fresh();
    }

    // Session actuellement ouverte pour une caisse, ou null.
    public function sessionActive(int $caisseId): ?SessionCaisse
    {
        return SessionCaisse::where('caisse_id', $caisseId)
            ->where('statut', 'ouverte')
            ->first();
    }

    // Première session ouverte trouvée pour l'école (toutes caisses
    // confondues) — utilisée par PaiementController pour rattacher
    // automatiquement un paiement en espèces à une session de caisse.
    public function sessionActivePourEcole(int $ecoleId): ?SessionCaisse
    {
        return SessionCaisse::whereHas('caisse', fn ($q) => $q->where('ecole_id', $ecoleId))
            ->where('statut', 'ouverte')
            ->orderByDesc('date_ouverture')
            ->first();
    }

    // Sessions fermées d'une caisse, filtrables par période d'ouverture.
    public function historiqueSessions(int $caisseId, ?string $dateDebut = null, ?string $dateFin = null)
    {
        return SessionCaisse::where('caisse_id', $caisseId)
            ->where('statut', 'fermee')
            ->when($dateDebut, fn ($q) => $q->whereDate('date_ouverture', '>=', $dateDebut))
            ->when($dateFin, fn ($q) => $q->whereDate('date_ouverture', '<=', $dateFin))
            ->orderByDesc('date_ouverture')
            ->get();
    }
}
