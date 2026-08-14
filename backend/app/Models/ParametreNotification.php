<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class ParametreNotification extends Model
{
    use FiltreParEcole;

    protected $table = 'parametres_notifications';

    protected $fillable = [
        'ecole_id',
        'cle',
        'valeur',
    ];

    protected function casts(): array
    {
        return [
            'valeur' => 'boolean',
        ];
    }

    // Déclencheurs automatiques disponibles : clé technique => libellé.
    public const DECLENCHEURS = [
        'notes_validees'      => "Notifier les parents quand les résultats d'une classe sont validés",
        'paiement_enregistre' => 'Notifier le parent quand un paiement est enregistré',
        'impaye'              => 'Notifier le parent en cas d\'impayé',
        'bulletin_disponible' => 'Notifier le parent quand un bulletin est disponible',
        'absence'             => 'Notifier le parent en cas d\'absence',
    ];

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    // Absence de ligne pour (ecole, cle) = déclencheur actif par défaut.
    public static function estActif(int $ecoleId, string $cle): bool
    {
        $parametre = static::withoutGlobalScope('parEcole')
            ->where('ecole_id', $ecoleId)
            ->where('cle', $cle)
            ->first();

        return $parametre?->valeur ?? true;
    }
}
