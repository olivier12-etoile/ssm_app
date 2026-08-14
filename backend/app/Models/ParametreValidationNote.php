<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ParametreValidationNote extends Model
{
    protected $table = 'parametres_validation_notes';

    // Rôles autorisés à valider les notes quand aucune valeur n'est enregistrée.
    public const ROLES_VALIDATION_DEFAUT = ['directeur', 'censeur'];

    protected $fillable = [
        'ecole_id',
        'validation_obligatoire',
        'roles_autorises_validation',
        'modification_apres_validation',
        'verrouillage_auto_cloture_periode',
    ];

    protected function casts(): array
    {
        return [
            'validation_obligatoire' => 'boolean',
            'roles_autorises_validation' => 'array',
            'modification_apres_validation' => 'boolean',
            'verrouillage_auto_cloture_periode' => 'boolean',
        ];
    }

    // roles_autorises_validation peut être vide (colonne nullable) : ce
    // helper renvoie la liste effective à utiliser, avec le défaut appliqué.
    public function rolesAutorisesOuDefaut(): array
    {
        return $this->roles_autorises_validation ?: self::ROLES_VALIDATION_DEFAUT;
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }
}
