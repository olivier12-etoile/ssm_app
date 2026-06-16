<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Ecole extends Model
{
    protected $table = 'ecoles';

    protected $fillable = [
        'nom',
        'code_ecole',
        'chemin_logo',
        'couleur_primaire',
        'couleur_secondaire',
        'telephone',
        'adresse',
        'statut_abonnement',
        'expire_le',
    ];

    public function utilisateurs()
    {
        return $this->hasMany(User::class, 'ecole_id');
    }

    public function classes()
    {
        return $this->hasMany(Classe::class, 'ecole_id');
    }

    public function annees()
    {
        return $this->hasMany(AnneeAcademique::class, 'ecole_id');
    }

    public function eleves()
    {
        return $this->hasMany(Eleve::class, 'ecole_id');
    }
}