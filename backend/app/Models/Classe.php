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
    ];

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
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
}