<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class ExonerationEleve extends Model
{
    use FiltreParEcole;

    protected $table = 'exonerations_eleves';

    protected $fillable = [
        'ecole_id',
        'eleve_id',
        'frais_scolaire_id',
        'type',
        'justification',
        'autorise_par',
    ];

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }

    public function fraisScolaire()
    {
        return $this->belongsTo(FraisScolaire::class, 'frais_scolaire_id');
    }

    public function autorisePar()
    {
        return $this->belongsTo(User::class, 'autorise_par');
    }
}
