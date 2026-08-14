<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ParametreMatiere extends Model
{
    protected $table = 'parametres_matieres';

    protected $fillable = [
        'ecole_id',
        'systeme_coefficients',
        'matieres_facultatives_autorisees',
    ];

    protected function casts(): array
    {
        return [
            'matieres_facultatives_autorisees' => 'boolean',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }
}
