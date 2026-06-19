<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Absence extends Model
{
    protected $table = 'absences';

    protected $fillable = [
        'eleve_id',
        'classe_id',
        'date_absence',
        'justifiee',
        'motif',
        'marque_par',
        'notifie',
    ];

    protected $casts = [
        'justifiee'    => 'boolean',
        'notifie'      => 'boolean',
        'date_absence' => 'date',
    ];

    public function eleve()
    {
        return $this->belongsTo(Eleve::class, 'eleve_id');
    }

    public function classe()
    {
        return $this->belongsTo(Classe::class, 'classe_id');
    }

    public function enseignant()
    {
        return $this->belongsTo(User::class, 'marque_par');
    }
}