<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CahierTexte extends Model
{
    protected $table = 'cahier_texte';

    protected $fillable = [
        'classe_id',
        'matiere_id',
        'enseignant_id',
        'date_cours',
        'cours_du_jour',
        'exercices',
        'devoir',
        'date_remise_devoir',
    ];

    protected $casts = [
        'date_cours'         => 'date',
        'date_remise_devoir' => 'date',
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
}
