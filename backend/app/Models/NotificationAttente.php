<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NotificationAttente extends Model
{
    protected $table = 'notifications_attente';

    protected $fillable = [
        'ecole_id',
        'eleve_id',
        'user_id',
        'type',
        'telephone_parent',
        'message',
        'statut',
        'envoyee_le',
    ];

    protected $casts = [
        'envoyee_le' => 'datetime',
    ];

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function destinataire()
    {
        return $this->hasOne(NotificationDestinataire::class, 'notification_attente_id');
    }
}