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
}