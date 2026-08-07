<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class RemiseEleve extends Model
{
    use FiltreParEcole;

    protected $table = 'remises_eleves';

    protected $fillable = [
        'ecole_id',
        'eleve_id',
        'frais_scolaire_id',
        'type',
        'montant',
        'pourcentage',
        'motif',
        'autorise_par',
    ];

    protected function casts(): array
    {
        return [
            'montant'     => 'decimal:2',
            'pourcentage' => 'decimal:2',
        ];
    }

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
