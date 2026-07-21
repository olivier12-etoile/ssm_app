<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Sanction extends Model
{
    protected $table = 'sanctions';

    protected $fillable = [
        'eleve_id',
        'classe_id',
        'type',
        'description',
        'date_sanction',
        'notifie_parent',
        'prononce_par',
    ];

    protected $casts = [
        'date_sanction'  => 'date',
        'notifie_parent' => 'boolean',
    ];

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }

    public function classe()
    {
        return $this->belongsTo(Classe::class, 'classe_id');
    }

    public function auteur()
    {
        return $this->belongsTo(User::class, 'prononce_par');
    }
}
