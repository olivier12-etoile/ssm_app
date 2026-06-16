<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PeriodeAcademique extends Model
{
    protected $table = 'periodes_academiques';

    protected $fillable = [
        'annee_academique_id',
        'nom',
        'date_debut',
        'date_fin',
        'statut',
    ];

    public function annee()
    {
        return $this->belongsTo(AnneeAcademique::class, 'annee_academique_id');
    }

    public function notes()
    {
        return $this->hasMany(Note::class, 'periode_id');
    }
}