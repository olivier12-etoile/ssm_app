<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class EcheanceFrais extends Model
{
    protected $table = 'echeances_frais';

    protected $fillable = [
        'frais_scolaire_id',
        'libelle',
        'montant',
        'date_limite',
        'ordre',
    ];

    protected function casts(): array
    {
        return [
            'montant'     => 'decimal:2',
            'date_limite' => 'date',
            'ordre'       => 'integer',
        ];
    }

    public function fraisScolaire()
    {
        return $this->belongsTo(FraisScolaire::class, 'frais_scolaire_id');
    }

    public function paiements()
    {
        return $this->hasMany(Paiement::class, 'echeance_id');
    }
}
