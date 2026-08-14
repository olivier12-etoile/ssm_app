<?php

namespace App\Models;

use App\Traits\FiltreParEcole;
use Illuminate\Database\Eloquent\Model;

class Caisse extends Model
{
    use FiltreParEcole;

    protected $table = 'caisses';

    protected $fillable = [
        'ecole_id',
        'nom',
        'actif',
    ];

    protected function casts(): array
    {
        return [
            'actif' => 'boolean',
        ];
    }

    public function ecole()
    {
        return $this->belongsTo(Ecole::class, 'ecole_id');
    }

    public function sessions()
    {
        return $this->hasMany(SessionCaisse::class, 'caisse_id');
    }
}
