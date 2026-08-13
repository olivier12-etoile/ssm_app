<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class JourTravaille extends Model
{
    use FiltreParEcole;

    protected $table = 'jours_travailles';

    protected $fillable = [
        'ecole_id',
        'jour',
        'actif',
        'annee_scolaire_id',
    ];

    protected function casts(): array
    {
        return [
            'actif' => 'boolean',
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
