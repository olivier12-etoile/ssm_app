<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class ModeleMessage extends Model
{
    use FiltreParEcole;

    protected $table = 'modeles_messages';

    protected $fillable = [
        'ecole_id',
        'nom',
        'categorie',
        'contenu',
        'variables_disponibles',
        'actif',
        'modifiable',
    ];

    protected $appends = ['variables_utilisees'];

    protected function casts(): array
    {
        return [
            'variables_disponibles' => 'array',
            'actif' => 'boolean',
            'modifiable' => 'boolean',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function notifications()
    {
        return $this->hasMany(Notification::class, 'modele_message_id');
    }

    /**
     * Variables réellement présentes dans le contenu (ex: {parent}, {eleve}),
     * extraites automatiquement par regex plutôt que déclarées à la main.
     */
    public function getVariablesUtiliseesAttribute(): array
    {
        preg_match_all('/\{([a-zA-Z0-9_]+)\}/', (string) $this->contenu, $matches);

        return array_values(array_unique($matches[1]));
    }
}
