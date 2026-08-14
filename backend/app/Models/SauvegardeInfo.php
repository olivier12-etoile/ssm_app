<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class SauvegardeInfo extends Model
{
    use FiltreParEcole;

    protected $table = 'sauvegardes_info';

    protected $fillable = [
        'ecole_id',
        'date_derniere_sauvegarde',
        'statut',
        'taille_fichier',
    ];

    protected function casts(): array
    {
        return [
            'date_derniere_sauvegarde' => 'datetime',
            'taille_fichier' => 'integer',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }
}
