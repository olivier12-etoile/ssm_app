<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\NotificationAttente;
use App\Models\NotificationDestinataire;
use Illuminate\Support\Facades\DB;

/**
 * Orchestration de l'envoi manuel de notifications. Le canal 'whatsapp'
 * s'appuie entièrement sur la queue notifications_attente déjà existante
 * (mode chaîne, wa.me) : cette classe ne fait qu'y déposer des entrées, elle
 * n'envoie jamais rien elle-même via une API payante.
 */
class EnvoiNotificationService
{
    public function __construct(
        private CiblageNotificationService $ciblageService,
        private VariableNotificationService $variableService,
    ) {
    }

    /**
     * Résout les destinataires et crée notifications + notification_destinataires.
     * N'envoie rien : voir envoyerMaintenant().
     */
    public function creerNotification(int $ecoleId, int $creePar, array $donnees): Notification
    {
        $destinataires = $this->ciblageService->resoudreDestinataires(
            $ecoleId,
            $donnees['type_cible'],
            $donnees['cibles'] ?? null
        );

        return DB::transaction(function () use ($ecoleId, $creePar, $donnees, $destinataires) {
            $programmee = $donnees['programmee'] ?? false;

            $notification = Notification::create([
                'ecole_id'             => $ecoleId,
                'titre'                => $donnees['titre'],
                'message'              => $donnees['message'],
                'modele_message_id'    => $donnees['modele_message_id'] ?? null,
                'type_cible'           => $donnees['type_cible'],
                'cibles'               => $donnees['cibles'] ?? null,
                'canal'                => $donnees['canal'],
                'urgent'               => $donnees['urgent'] ?? false,
                'programmee'           => $programmee,
                'date_envoi_prevue'    => $donnees['date_envoi_prevue'] ?? null,
                'statut'               => $programmee ? 'programmee' : 'preparation',
                'cree_par'             => $creePar,
                'nombre_destinataires' => $destinataires->count(),
            ]);

            foreach ($destinataires as $destinataire) {
                NotificationDestinataire::create([
                    'notification_id'  => $notification->id,
                    'eleve_id'         => $destinataire['eleve_id'],
                    'user_id'          => $destinataire['user_id'],
                    'nom_destinataire' => $destinataire['nom'],
                    'telephone'        => $destinataire['telephone'],
                    'statut'           => 'en_attente',
                ]);
            }

            return $notification->fresh('destinataires');
        });
    }

    /**
     * Déclenche l'envoi effectif d'une notification déjà créée :
     * - whatsapp : pousse chaque destinataire dans notifications_attente
     *   (avec variables remplacées), à envoyer manuellement via le mode chaîne
     * - interne  : marque directement comme délivré (visible dans l'app)
     * - sms/email : pas d'infrastructure d'envoi dans SSM, marqué en échec
     */
    public function envoyerMaintenant(int $notificationId): Notification
    {
        $notification = Notification::with('destinataires')->findOrFail($notificationId);

        // Certains déclencheurs (ex: résultats d'une classe) veulent que
        // {periode}/{moyenne} reflètent une période précise plutôt que la
        // période active courante de l'école — portée via cibles.periode_id.
        $periodeId = $notification->cibles['periode_id'] ?? null;

        // De même, un déclencheur peut porter des valeurs figées pour
        // {classe}/{matiere}/{date} (ex: appel de présence) plutôt que de
        // laisser VariableNotificationService les déduire par défaut.
        $variablesSupplementaires = array_intersect_key(
            $notification->cibles ?? [],
            array_flip(['classe', 'matiere', 'date'])
        );

        $nombreEnvoyes = 0;
        $nombreEchoues = 0;

        foreach ($notification->destinataires as $destinataire) {
            if ($notification->canal === 'whatsapp') {
                if (!$destinataire->telephone) {
                    $destinataire->update(['statut' => 'echec']);
                    $nombreEchoues++;
                    continue;
                }

                $message = $destinataire->eleve_id
                    ? $this->variableService->remplacerVariables($notification->message, $destinataire->eleve_id, $periodeId, $variablesSupplementaires)
                    : $notification->message;

                $notificationAttente = NotificationAttente::create([
                    'ecole_id'         => $notification->ecole_id,
                    'eleve_id'         => $destinataire->eleve_id,
                    'user_id'          => $destinataire->user_id,
                    'type'             => 'notification',
                    'telephone_parent' => $destinataire->telephone,
                    'message'          => $message,
                    'statut'           => 'en_attente',
                ]);

                $destinataire->update([
                    'statut'                  => 'envoye',
                    'notification_attente_id' => $notificationAttente->id,
                ]);

                $nombreEnvoyes++;
            } elseif ($notification->canal === 'interne') {
                if (!$destinataire->user_id) {
                    $destinataire->update(['statut' => 'echec']);
                    $nombreEchoues++;
                    continue;
                }

                $destinataire->update(['statut' => 'delivre']);
                $nombreEnvoyes++;
            } else {
                $destinataire->update(['statut' => 'echec']);
                $nombreEchoues++;
            }
        }

        $statut = 'envoyee';
        if ($nombreEchoues > 0 && $nombreEnvoyes > 0) {
            $statut = 'echec_partiel';
        } elseif ($nombreEchoues > 0 && $nombreEnvoyes === 0) {
            $statut = 'echec';
        }

        $notification->update([
            'statut'         => $statut,
            'nombre_envoyes' => $nombreEnvoyes,
            'nombre_echoues' => $nombreEchoues,
        ]);

        return $notification->fresh('destinataires');
    }
}
