<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class Notification extends Model
{
    use FiltreParEcole;

    protected $table = 'notifications';

    protected $fillable = [
        'ecole_id',
        'titre',
        'message',
        'modele_message_id',
        'type_cible',
        'cibles',
        'canal',
        'urgent',
        'programmee',
        'date_envoi_prevue',
        'statut',
        'cree_par',
        'nombre_destinataires',
        'nombre_envoyes',
        'nombre_echoues',
    ];

    protected function casts(): array
    {
        return [
            'cibles' => 'array',
            'urgent' => 'boolean',
            'programmee' => 'boolean',
            'date_envoi_prevue' => 'datetime',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function modeleMessage()
    {
        return $this->belongsTo(ModeleMessage::class, 'modele_message_id');
    }

    public function auteur()
    {
        return $this->belongsTo(User::class, 'cree_par');
    }

    public function destinataires()
    {
        return $this->hasMany(NotificationDestinataire::class, 'notification_id');
    }
}
