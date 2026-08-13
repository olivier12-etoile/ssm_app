<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class EvenementCalendrier extends Model
{
    use FiltreParEcole;

    protected $table = 'evenements_calendrier';

    protected $fillable = [
        'ecole_id',
        'annee_scolaire_id',
        'type',
        'libelle',
        'date_debut',
        'date_fin',
    ];

    protected function casts(): array
    {
        return [
            'date_debut' => 'date',
            'date_fin' => 'date',
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
