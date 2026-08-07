<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ParentEleve extends Model
{
    protected $table = 'parents_eleves';

    protected $fillable = [
        'eleve_id',
        'nom',
        'prenom',
        'lien_parente',
        'telephone_principal',
        'telephone_secondaire',
        'adresse',
        'profession',
    ];

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }
}
