<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ClasseMatiere extends Model
{
    protected $table = 'classe_matiere';

    protected $fillable = [
        'classe_id',
        'matiere_id',
        'coefficient',
    ];

    public function classe()
    {
        return $this->belongsTo(Classe::class, 'classe_id');
    }

    public function matiere()
    {
        return $this->belongsTo(Matiere::class, 'matiere_id');
    }
}
