<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class VerrouillageNote extends Model
{
    protected $table = 'verrouillages_notes';

    protected $fillable = [
        'saisie_note_id',
        'verrouille',
        'deverrouille_par',
        'motif_deverrouillage',
        'date_deverrouillage',
    ];

    protected function casts(): array
    {
        return [
            'verrouille' => 'boolean',
            'date_deverrouillage' => 'datetime',
        ];
    }

    public function saisieNote()
    {
        return $this->belongsTo(SaisieNote::class, 'saisie_note_id');
    }

    public function deverrouillePar()
    {
        return $this->belongsTo(User::class, 'deverrouille_par');
    }
}
