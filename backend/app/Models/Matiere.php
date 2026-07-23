<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Matiere extends Model
{
    protected $table = 'matieres';

    protected $fillable = [
        'ecole_id',
        'nom',
        'code',
        'couleur',
        'coefficient',
    ];

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function notes()
    {
        return $this->hasMany(Note::class, 'matiere_id');
    }

    public function evaluations()
    {
        return $this->hasMany(Evaluation::class, 'matiere_id');
    }

    public function classeMatieres()
    {
        return $this->hasMany(ClasseMatiere::class, 'matiere_id');
    }

    public function enseignants()
    {
        return $this->belongsToMany(
            User::class,
            'enseignant_classe_matiere',
            'matiere_id',
            'enseignant_id'
        )->distinct();
    }
}