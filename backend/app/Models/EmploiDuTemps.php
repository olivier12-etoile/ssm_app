<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class EmploiDuTemps extends Model
{
    protected $table = 'emplois_du_temps';

    protected $fillable = [
        'ecole_id',
        'classe_id',
        'annee_academique_id',
        'jour',
        'heure_debut',
        'heure_fin',
        'matiere_id',
        'enseignant_id',
        'salle',
    ];

    protected $casts = [
        'heure_debut' => 'string',
        'heure_fin'   => 'string',
    ];

    public function classe()
    {
        return $this->belongsTo(Classe::class, 'classe_id');
    }

    public function matiere()
    {
        return $this->belongsTo(Matiere::class, 'matiere_id');
    }

    public function enseignant()
    {
        return $this->belongsTo(User::class, 'enseignant_id');
    }

    public function annee()
    {
        return $this->belongsTo(AnneeAcademique::class, 'annee_academique_id');
    }
}
