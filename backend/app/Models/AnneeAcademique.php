<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AnneeAcademique extends Model
{
    protected $table = 'annees_academiques';

    protected $fillable = [
        'ecole_id',
        'libelle',
        'date_debut',
        'date_fin',
        'statut',
    ];

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function periodes()
    {
        return $this->hasMany(PeriodeAcademique::class, 'annee_academique_id');
    }

    public function inscriptions()
    {
        return $this->hasMany(Inscription::class, 'annee_academique_id');
    }
}