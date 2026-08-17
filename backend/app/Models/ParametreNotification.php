<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class ParametreNotification extends Model
{
    use FiltreParEcole;

    protected $table = 'parametres_notifications';

    protected $fillable = [
        'ecole_id',
        'cible',
        'cle',
        'valeur',
    ];

    protected function casts(): array
    {
        return [
            'valeur' => 'boolean',
        ];
    }

    // Déclencheurs automatiques disponibles (module Notifications,
    // DeclencheurNotificationService) : clé technique => libellé. Toujours
    // ciblés "parents" — distincts de TYPES_NOTIFICATIONS ci-dessous, qui
    // liste les TYPES de notifications que l'école accepte de recevoir
    // (module Paramètres de l'École, ParametreNotificationEcoleController).
    public const DECLENCHEURS = [
        'notes_validees'      => "Notifier les parents quand les résultats d'une classe sont validés",
        'paiement_enregistre' => 'Notifier le parent quand un paiement est enregistré',
        'impaye'              => 'Notifier le parent en cas d\'impayé',
        'bulletin_disponible' => 'Notifier le parent quand un bulletin est disponible',
        'absence'             => 'Notifier le parent en cas d\'absence',
        'retard'              => 'Notifier le parent en cas de retard',
    ];

    // Types de notifications acceptés par l'école, par destinataire
    // (cible => [clé => libellé]). Géré par ParametreNotificationEcoleController
    // et pré-rempli (tous actifs) par ParametresNotificationsEcoleSeeder pour
    // chaque nouvelle école.
    public const TYPES_NOTIFICATIONS = [
        'parents' => [
            'bulletin'        => 'Bulletin disponible',
            'absence'         => "Absence de l'élève",
            'retard'          => "Retard de l'élève",
            'paiement_recu'   => 'Paiement reçu',
            'paiement_retard' => 'Paiement en retard',
            'convocation'     => 'Convocation',
            'info_generale'   => 'Information générale',
        ],
        'enseignants' => [
            'nouvelle_periode'   => 'Nouvelle période ouverte',
            'date_limite_saisie' => 'Date limite de saisie des notes',
            'notes_retournees'   => 'Notes retournées (rejetées)',
            'notes_validees'     => 'Notes validées',
        ],
    ];

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    // Absence de ligne pour (ecole, parents, cle) = déclencheur actif par défaut.
    public static function estActif(int $ecoleId, string $cle): bool
    {
        $parametre = static::withoutGlobalScope('parEcole')
            ->where('ecole_id', $ecoleId)
            ->where('cible', 'parents')
            ->where('cle', $cle)
            ->first();

        return $parametre?->valeur ?? true;
    }
}
