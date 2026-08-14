<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NotificationDestinataire extends Model
{
    protected $table = 'notification_destinataires';

    protected $fillable = [
        'notification_id',
        'eleve_id',
        'user_id',
        'nom_destinataire',
        'telephone',
        'statut',
        'notification_attente_id',
    ];

    public function notification()
    {
        return $this->belongsTo(Notification::class, 'notification_id');
    }

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function notificationAttente()
    {
        return $this->belongsTo(NotificationAttente::class, 'notification_attente_id');
    }
}
