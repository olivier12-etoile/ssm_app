<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AppreciationBulletin extends Model
{
    protected $table = 'appreciations_bulletins';

    protected $fillable = [
        'eleve_id',
        'periode_id',
        'appreciation_enseignant',
        'appreciation_directeur',
        'observation',
    ];

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }

    public function periode()
    {
        return $this->belongsTo(PeriodeAcademique::class, 'periode_id');
    }
}