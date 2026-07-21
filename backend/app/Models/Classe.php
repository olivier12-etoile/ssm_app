<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Classe extends Model
{
    protected $table = 'classes';

    protected $fillable = [
        'ecole_id',
        'nom',
        'niveau',
        'capacite_max',
        'serie',
        'salle',
        'statut',
        'professeur_principal_id',
        'annee_academique_id',
    ];

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function professeurPrincipal()
    {
        return $this->belongsTo(User::class, 'professeur_principal_id');
    }

    public function annee()
    {
        return $this->belongsTo(AnneeAcademique::class, 'annee_academique_id');
    }

    public function inscriptions()
    {
        return $this->hasMany(Inscription::class, 'classe_id');
    }

    public function enseignants()
    {
        return $this->belongsToMany(User::class, 'enseignant_classe_matiere', 'classe_id', 'enseignant_id')
                    ->withPivot('matiere_id')
                    ->withTimestamps();
    }

    public function matieres()
    {
        return $this->belongsToMany(Matiere::class, 'classe_matiere', 'classe_id', 'matiere_id')
                    ->withPivot('coefficient');
    }
}