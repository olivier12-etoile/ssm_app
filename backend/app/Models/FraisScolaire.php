<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class FraisScolaire extends Model
{
    protected $table = 'frais_scolaires';

    protected $fillable = [
        'ecole_id',
        'classe_id',
        'annee_academique_id',
        'type',
        'montant_total',
        'montant_tranche_1',
        'montant_tranche_2',
        'montant_tranche_3',
    ];

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function classe()
    {
        return $this->belongsTo(Classe::class, 'classe_id');
    }

    public function annee()
    {
        return $this->belongsTo(AnneeAcademique::class, 'annee_academique_id');
    }
}
