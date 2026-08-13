<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class CreneauHoraire extends Model
{
    use FiltreParEcole;

    protected $table = 'creneaux_horaires';

    protected $fillable = [
        'ecole_id',
        'libelle',
        'heure_debut',
        'heure_fin',
        'ordre',
        'type',
        'annee_scolaire_id',
    ];

    protected function casts(): array
    {
        return [
            'heure_debut' => 'datetime:H:i',
            'heure_fin' => 'datetime:H:i',
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

    public function seances()
    {
        return $this->hasMany(Seance::class, 'creneau_horaire_id');
    }
}
