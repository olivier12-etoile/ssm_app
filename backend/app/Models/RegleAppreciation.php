<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class RegleAppreciation extends Model
{
    use FiltreParEcole;

    protected $table = 'regles_appreciation';

    protected $fillable = [
        'ecole_id',
        'note_min',
        'note_max',
        'libelle_appreciation',
    ];

    protected function casts(): array
    {
        return [
            'note_min' => 'decimal:2',
            'note_max' => 'decimal:2',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    /**
     * Trouve la règle du barème correspondant à une note donnée. Si
     * $ecoleId est fourni, la recherche ignore le scope global "parEcole"
     * (utile hors contexte authentifié, ex. job en file d'attente).
     */
    public static function pourNote(float $note, ?int $ecoleId = null): ?self
    {
        $query = $ecoleId
            ? static::withoutGlobalScope('parEcole')->where('ecole_id', $ecoleId)
            : static::query();

        return $query->where('note_min', '<=', $note)
            ->where('note_max', '>=', $note)
            ->first();
    }
}
