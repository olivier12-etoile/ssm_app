<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ParametreFrais extends Model
{
    protected $table = 'parametres_frais';

    protected $fillable = [
        'ecole_id',
        'devise',
        'nombre_tranches_defaut',
        'penalites_actives',
        'montant_penalite_retard',
        'paiement_partiel_autorise',
        'seuil_jours_retard_non_en_regle',
    ];

    protected function casts(): array
    {
        return [
            'nombre_tranches_defaut' => 'integer',
            'penalites_actives' => 'boolean',
            'montant_penalite_retard' => 'decimal:2',
            'paiement_partiel_autorise' => 'boolean',
            'seuil_jours_retard_non_en_regle' => 'integer',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }
}
