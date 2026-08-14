<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class InstantaneStatistique extends Model
{
    use FiltreParEcole;

    protected $table = 'instantanes_statistiques';

    protected $fillable = [
        'ecole_id',
        'annee_scolaire_id',
        'type',
        'donnees',
        'date_snapshot',
    ];

    protected function casts(): array
    {
        return [
            'donnees'       => 'array',
            'date_snapshot' => 'datetime',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function anneeScolaire()
    {
        return $this->belongsTo(AnneeAcademique::class, 'annee_scolaire_id');
    }
}
