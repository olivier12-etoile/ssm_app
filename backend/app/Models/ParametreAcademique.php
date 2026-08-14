<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ParametreAcademique extends Model
{
    protected $table = 'parametres_academiques';

    protected $fillable = [
        'ecole_id',
        'bareme_note_max',
        'coefficients_par_matiere',
        'coefficients_par_classe',
        'coefficients_par_niveau',
        'mode_calcul_moyenne_matiere',
    ];

    protected function casts(): array
    {
        return [
            'bareme_note_max' => 'integer',
            'coefficients_par_matiere' => 'boolean',
            'coefficients_par_classe' => 'boolean',
            'coefficients_par_niveau' => 'boolean',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }
}
