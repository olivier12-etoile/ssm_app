<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ParametreBulletin extends Model
{
    protected $table = 'parametres_bulletins';

    protected $fillable = [
        'ecole_id',
        'afficher_logo',
        'afficher_matricule',
        'afficher_effectif',
        'afficher_coefficients',
        'afficher_rang',
        'afficher_appreciations',
        'afficher_absences',
        'afficher_retards',
        'afficher_decision_conseil',
        'afficher_signature_directeur',
        'afficher_cachet',
        'modele_bulletin',
    ];

    protected function casts(): array
    {
        return [
            'afficher_logo' => 'boolean',
            'afficher_matricule' => 'boolean',
            'afficher_effectif' => 'boolean',
            'afficher_coefficients' => 'boolean',
            'afficher_rang' => 'boolean',
            'afficher_appreciations' => 'boolean',
            'afficher_absences' => 'boolean',
            'afficher_retards' => 'boolean',
            'afficher_decision_conseil' => 'boolean',
            'afficher_signature_directeur' => 'boolean',
            'afficher_cachet' => 'boolean',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }
}
